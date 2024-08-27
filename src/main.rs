use clap::Parser;
use log::{debug, error, info};

mod download;
mod utilities;


#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {

	utilities::setup_logger()?;
	
	// display the debugging mode availability
	debug!(
		"Debugging mode enabled: {}", 
		log::log_enabled!(log::Level::Debug)
	);

    let mut arguments = download::DownloadArguments::parse();
    
    info!(
    	"Concurrency is sat to: {}", &arguments.tasks
    );
    
    // handle the case in which the repo exists locally
    if std::path::Path::new(&arguments.repository).exists() {
    	println!(
     		"Repository has detected in the current working directory, overwrite?(Y/N)"
     	);
    	let mut buffer = String::new();
    	std::io::stdin()
     		.read_line(&mut buffer)
       		.expect("Incorrect input");
     	let user_input = buffer.trim();
     
     	let confirm_instructions = vec!["y", "Y"];
      	let negative_instructions = vec!["n", "N"];
       
       	if confirm_instructions.contains(&user_input) {
        	std::fs::remove_dir_all(&arguments.repository)
            	.expect("Error when trying to delete the directory");
        } else if negative_instructions.contains(&user_input) {
        	panic!("Aborted.");
        } else {
        	panic!("Wrong input. You either input y | Y, or n | N.")
        }
    }
    
    match arguments.clone_repository() {
    	Ok(result) => {
	    	match arguments.read_lfs_pointers(
				&result
					.path()
					.parent()
					.unwrap()
					.to_path_buf()
			) {
		     	Ok(lfs_files) => match arguments
						.extract_lfs_urls(
							&result
								.path()
								.parent()
								.unwrap()
								.to_path_buf(), 
							lfs_files,
							&"https://hf-mirror.com"
								.to_string()
					) {
				      	Ok(large_file_information) => arguments
							.download_files(
								large_file_information
							).await?,
				       	Err(error) => error!(
							"Downloading large files failed due to {}", 
							error
						)
				    },
				Err(error) => error!(
					"Extracting LFS urls failed due to {}", error
				)
		    };
			
			info!(
	     		"Git cloned the repository to: {}", result
	       			.path()
					.parent()
					.unwrap()
	          		.as_os_str()
	            	.to_os_string()
	             	.to_string_lossy()
	     	);
    	},
      	Err(error) => error!(
       		"Git clone has failed {}", error
        )
    };

    return Ok(());
}
