use simple_demo::media_util;

fn main() -> anyhow::Result<()> {
    let files = vec![
        "earth.png",
        "earth2.jpg"
    ];

    for file_name in files.iter() {
        println!("\n====={}=====", file_name);

        match imagesize::size(file_name) {
            Ok(size) => println!("Image dimensions: {}x{}", size.width, size.height),
            Err(why) => println!("Error getting dimensions: {:?}", why)
        }

        println!("{:?}", media_util::get_image_meta(file_name));
    }


    Ok(())
}
