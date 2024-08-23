use assert_cmd::Command;

#[test]
fn download_test() -> Result<(), Box<dyn std::error::Error>> {
	let mut command = Command::cargo_bin("rustyface")?;
	
	command
		.arg("--repository")
		.arg("sentence-transformers/all-MiniLM-L6-v2");
	
	command
		.arg("--tasks")
		.arg("4");
	
	command.assert().success();
	
	return Ok(());
}

#[test]
fn help_test() -> Result<(), Box<dyn std::error::Error>> {
	let mut command = Command::cargo_bin("rustyface")?;
	
	command.arg("--help");
	
	command.assert().success();
	
	return Ok(());
}