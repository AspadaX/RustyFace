use std::time::SystemTime;

use fern::{self, colors::{self, ColoredLevelConfig}};
use humantime;

pub fn setup_logger() -> Result<(), fern::InitError> {

	let colors = ColoredLevelConfig::new()
	    .info(colors::Color::Green)
	    .warn(colors::Color::Yellow)
	    .error(colors::Color::Red)
		.debug(colors::Color::White);

    fern::Dispatch::new()
        .format(move |out, message, record| {
            out.finish(format_args!(
                "[{} {} {}] {}",
                humantime::format_rfc3339_seconds(SystemTime::now()),
                colors.color(record.level()),
                record.target(),
                message
            ))
        })
	        .level(log::LevelFilter::Info)
	        .chain(std::io::stdout())
	        .apply()?;
    Ok(())
}