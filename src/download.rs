use std::io::{BufRead, Seek, Write};
use futures_util::StreamExt;
use glob::glob;

use clap::Parser;
use git2::{build::RepoBuilder, Repository};
use log::{info, warn, error, debug};
use indicatif;
use sha2::Digest;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
pub struct DownloadArguments {
	// below are cli arguments
    #[arg(required = true)]
    pub repository: String,
    #[arg(short, long, default_value_t = 4)]
    pub tasks: usize,
    
    // below are data that are needed for the program, NO NEED to be
    // passed from the cli arguments
    pub repository_local_path: Option<String>
}

impl DownloadArguments {
    pub fn clone_repository(&mut self) -> Result<Repository, Box<dyn std::error::Error>> {

   		info!(
	     	"Attempting to clone the repository: {}",
			&self.repository
	    );
		fn ensure_trailing_slash(s: &str) -> String {
			if !s.ends_with('/') {
				format!("{}{}", s, '/')
			} else {
				s.to_string()
			}
		}
		
        // set the url with a base url
        let mut url = ensure_trailing_slash(
        	option_env!("HF_ENDPOINT")
         		.unwrap_or("https://hf-mirror.com/")
        );
        url.push_str(self.repository.as_str());

        let path_to_join = std::path::Path::new(&self.repository);

        // get the working directory as the place to clone the repository
        let working_directory_buffer = std::env::current_dir()?;
        let working_directory = working_directory_buffer
        	.join(path_to_join);
        
        let repository = RepoBuilder::new()
        	.clone(
         		&url,
           		&working_directory
         	)?;
        
        // store the repository path to the struct for future calls.
        self.repository_local_path = Some(
	        repository
	        	.path()
	         	.parent()
	          	.unwrap()
	          	.to_string_lossy()
	           	.to_string()
	    );

        // clone the repository to the specified directory
        return Ok(repository);
    }
    
    pub fn read_lfs_pointers(
    	&self,
     	repository_path: &std::path::PathBuf
    ) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    	let gitattributes_path = repository_path.join(".gitattributes");
     	debug!(
      		"As detected, `.gitattributes` file is located at: {:?}", 
        	&gitattributes_path
      	);
      
     	let file = std::fs::File::open(gitattributes_path)?;
      	let reader = std::io::BufReader::new(file);
	    let mut lfs_files: Vec<String> = Vec::new();
		
		for line in reader.lines() {
			let line = line?;
			if line.contains("filter=lfs") {
				let parts: Vec<&str> = line.split_whitespace().collect();
				if let Some(pattern) = parts.get(0) {
					let pattern_path = repository_path.join(pattern);
					for entry in glob(pattern_path.to_str().unwrap())? {
						match entry {
							Ok(result) => {
								lfs_files.push(result.file_name().unwrap().to_string_lossy().to_string());
								debug!("LFS filepath extracted: {:?}", result);
							},
							Err(error) => error!(
								"LFS filepath pattern ({}) reading error occurred: {}", 
								pattern, 
								error
							)
						}
					}
				}
			}
		}
       
       	return Ok(lfs_files);
    }

    pub fn extract_lfs_urls(
    	&self,
     	repository_path: &std::path::PathBuf,
      	lfs_files: Vec<String>,
       	base_url: &String
    ) -> Result<Vec<LargeFileInformation>, std::io::Error> {
    
   		debug!(
	    	"Trying to locate filepath at: {:?}", &repository_path
	    );
			
    	let mut large_file_information: Vec<LargeFileInformation> = Vec::new();

     	for lfs_file in lfs_files {
      		
	      	let pointer_filepath = repository_path.join(&lfs_file);
			debug!("Pointer filepath is located at {:?}", pointer_filepath);
			
	       	let file = std::fs::File::open(pointer_filepath)?;
			let reader = std::io::BufReader::new(file);
			
			let mut oid: Option<String> = None;

	        for line in reader.lines() {
	            let line = line?;
	            if line.starts_with("oid sha256:") {
	                oid = Some(line.replace("oid sha256:", "").trim().to_string());
	                break;
	            }
	        }
	
	        if let Some(oid) = oid {
	            let url = format!("{}/{}/resolve/main/{}", base_url, self.repository, &lfs_file);
	            debug!("Constructed URL: {}", &url);
				
	            large_file_information.push(
					LargeFileInformation::new(url, oid)
				);
	        } else {
	            debug!("OID not found in pointer file: {}", lfs_file);
	        }
			
	    }

		return Ok(large_file_information);
    }
    
    async fn download_single_file_resume(
        client: &reqwest::Client,
        url: &String,
        error: impl std::error::Error,
        file: &mut std::fs::File,
        hasher: &mut sha2::Sha256,
        download_progress: &mut u64,
        progress_bar: &indicatif::ProgressBar,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // get the ending position of the file
        let start = file.seek(std::io::SeekFrom::End(0))?;
        debug!(
           	"Resume from position: {}", &start
        );
        
        // set the start position to where it ended
        let retry = client
            .get(url)
            .header("Range", format!("bytes={}-", start))
            .send()
            .await?;
        
        let status = retry.status().is_success().clone();
        
        // for the purpose of debugging, we print the header
        let headers = retry.headers().clone();
        debug!(
           	"Headers when retrying: {:?}", headers
        );
        
        // streaming logic
        if status {
            let mut content = retry
               	.bytes_stream();
            
            while let Some(chunk) = content.next().await {
            	let chunk = chunk?;
	            file.write_all(&chunk)?;
	            hasher.update(&chunk);
	            
	            *download_progress += chunk.len() as u64;
	            progress_bar.set_position(*download_progress);
            }
        }
        
        return Ok(());
    }
	
    /// a single thread for downloading files
    async fn download_single_file(
     	client: reqwest::Client,
     	url: String,
      	repository_local_path: String,
       	progress_bar: std::sync::Arc<indicatif::MultiProgress>,
        expected_sha256: String,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    
  		info!(
			"Downloading from URL: {}", &url
		);
		
		// setup a hasher for verifying sha256
		let mut hasher = sha2::Sha256::new();	
		let filename = url.split("/").last().unwrap();
		let template_string = "{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {bytes}/{total_bytes} ({bytes_per_sec}, {eta}) - "
    		.to_string();
		let output_string = template_string + filename;
		
		// initiate the file download request
		let response = client
			.get(&url)
			.send()
			.await?;
		let total_filesize = response
			.content_length().ok_or("Failed to get filesize")?;
		
		// construct the eventual filepath,
		// make this file downloaded to the repository folder
		let filepath = std::path::Path::new(
			&repository_local_path
		).join(filename);
		
		// create a file for writing data
		let mut file = std::fs::File::create(filepath)?;
		
		// initiate the progress bar
		let pb = progress_bar.add(
			indicatif::ProgressBar::new(total_filesize)
		);
		pb.set_style(
			indicatif::ProgressStyle::default_bar()
           	.template(output_string.as_str())
               	.expect("Error when trying to render a progress bar")
           	.progress_chars("#>-")
		);
		let mut download_progress: u64 = 0;
		
		// check if the response is okay to perform saving logics
		if response.status().is_success() {
			
			let mut stream = response
				.bytes_stream();
			
			while let Some(item) = stream.next().await {
				match item {
					Ok(chunk) => {
						// write file chunk
						file.write_all(&chunk)?;
						
						// store sha256 of the chunk to the hasher
						hasher.update(&chunk);
						
						download_progress += chunk.len() as u64;
						pb.set_position(download_progress);
					},
					Err(error) => {
						loop {
							match DownloadArguments::download_single_file_resume(
								&client,
		                        &url,
		                        &error,
		                        &mut file,
		                        &mut hasher,
		                        &mut download_progress,
		                        &pb,
							).await {
								Ok(_) => break,
								Err(_) => continue
							};
						}
					}
				};
				
			}
			
		} else {
			
			error!(
				"Failed to download file: {} - Status: {}", 
				&url, response.status()
			);
			
		}
		
		let result_hash = format!("{:x}", hasher.finalize());
		if result_hash == expected_sha256 {
			info!(
				"SHA256 hash verification succeeded for file {}", 
				filename
			);
		} else {
			warn!(
				"SHA256 hash mismatch for file: {}. Expected: {}, Got: {}", 
				filename, expected_sha256, result_hash
			);
		}
		
		info!("Downloaded and saved file: {}", filename);
		
		// file.write_all(&content)?;
		pb.finish_with_message(
			format!("Downloaded {}", filename)
		);
		
		return Ok(());
    }
    
    pub async fn download_files(
    	&self,
     	large_file_information: Vec<LargeFileInformation>
    ) -> Result<(), Box<dyn std::error::Error>> {
    	let client = reqwest::Client::new();
      	
     	info!(
      		"Downloading client has initiated. {} large file(s) to be downloaded.", 
        	large_file_information.len()
      	);
      
      	if large_file_information.len() == 0 {
      		warn!(
        		"No LFS urls had been detected. This could potentially be an error?"
        	);
       	}
    
        let progress_bar = std::sync::Arc::new(
        	indicatif::MultiProgress::new()
        );
        let mut handlers = Vec::new();
        let semaphore = std::sync::Arc::new(
        	tokio::sync::Semaphore::new(
         		self.tasks
         	)
        );
        
    	for single_large_file_information in large_file_information {
     		let client_in_thread = client.clone();
       		let repository_local_path_thread = self.repository_local_path
         		.clone().unwrap();
         	let progress_bar_thread = progress_bar.clone();
          	let semaphore_thread = semaphore.clone();
         
     		let handler = tokio::task::spawn(
          		async move {
            		let _permit = semaphore_thread
              			.acquire().await.unwrap();
              		
	            	return DownloadArguments::download_single_file(
	            		client_in_thread, 
	              		single_large_file_information.url,
	                	repository_local_path_thread,
	                 	progress_bar_thread,
	                  	single_large_file_information.sha256
	            	).await;
            	}
       		);
       		handlers.push(handler);
	    }
		
		let mut results = Vec::new();
		// for calculating the number of failed tasks
		let total_handlers = handlers.len();
		
		for handler in handlers {
			let result = handler
				.await?
				.expect("Error happened when downloading a file");
			
			results.push(result);
		}
		
		if results.len() == total_handlers {
			info!("All downloads had been succeeded!");
		} else {
			let failures = total_handlers - results.len();
			warn!("{} downloads had failed.", failures);
		}
		
		return Ok(());
    }
    
}

pub struct LargeFileInformation {
	pub url: String,
	pub sha256: String
}

impl LargeFileInformation {
	fn new(url: String, sha256: String) -> Self {
		return LargeFileInformation {
			url: url,
			sha256: sha256
		}
	}
}