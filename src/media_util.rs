use std::path::Path;
use imageinfo::ImageInfo;
use serde::{Deserialize, Serialize};
use ffmpeg_next as ffmpeg;
use ffmpeg_next::{
    format::{ Pixel},
    software::scaling::{context::Context, flag::Flags},
    util::frame::video::Video as VideoFrame,
};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ImageMetadata {
    ext: String,
    mimetype: String,
    width: i64,
    height: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct VideoMetadata {
    duration: f64,
    pub video_bitrate: Option<usize>,
    pub video_codec: Option<String>,
    pub height: Option<u32>,
    pub width: Option<u32>,
    pub audio_codec: Option<String>,
    pub audio_bitrate: Option<usize>,
    pub audio_rate: Option<u32>,
    pub image_name: Option<String>,
}

pub fn get_image_meta(file_path: impl AsRef<Path>) -> Option<ImageMetadata> {
    match ImageInfo::from_file_path(file_path) {
        Ok(info) => {
            let meta = ImageMetadata {
                ext: info.ext.to_string(),
                mimetype: info.mimetype.to_string(),
                width: info.size.width,
                height: info.size.height,
            };
            Some(meta)
        }
        Err(_err) => { None }
    }
}

pub fn get_media_meta(file_path: impl AsRef<Path>, image_path: String, file_name: String) -> Option<VideoMetadata> {
    match ffmpeg::init() {
        Ok(_) => {}
        Err(_) => { return None }
    }

    match ffmpeg::format::input(&file_path) {
        Ok(mut ictx) => {
            let duration = ictx.duration() as f64 / f64::from(ffmpeg::ffi::AV_TIME_BASE);
            let mut width = None;
            let mut height = None;
            let mut video_codec = None;
            let mut video_bitrate = None;
            let mut image_name = None;
            if let Some(stream) = ictx.streams().best(ffmpeg::media::Type::Video) {
                if let Ok(context) = ffmpeg::codec::context::Context::from_parameters(stream.parameters()) {
                    video_codec.replace(context.id().name().to_string());
                    if let Ok(mut video) = context.decoder().video() {
                        video_bitrate.replace(video.bit_rate());
                        width.replace(video.width());
                        height.replace(video.height());

                        // 初始化缩放上下文（转换为 RGB24）
                        if let Ok(mut scaler) = Context::get(
                            video.format(),
                            video.width(),
                            video.height(),
                            Pixel::RGB24,
                            video.width(),
                            video.height(),
                            Flags::BILINEAR,
                        ) {
                            // 创建帧容器
                            let mut frame = VideoFrame::empty();
                            let mut rgb_frame = VideoFrame::empty();

                            // 读取数据包直到找到第一个视频帧
                            for (stream, packet) in ictx.packets() {
                                if stream.index() != stream.index() {
                                    continue;
                                }

                                // 发送数据包到解码器
                                if let Ok(_) = video.send_packet(&packet) {
                                    // 接收解码后的帧
                                    if video.receive_frame(&mut frame).is_ok() {
                                        // 执行颜色空间转换
                                        if let Ok(_) = scaler.run(&frame, &mut rgb_frame) {
                                            let full_path = format!("{}/{}", &image_path, &file_name);
                                            // 保存为图片文件
                                            match save_frame_as_image(&rgb_frame, full_path) {
                                                Ok(_) => {
                                                    image_name.replace(file_name);
                                                }
                                                Err(e) => {println!("{:?}", e)}
                                            }
                                            break; // 找到第一帧后退出
                                        }
                                    }
                                }

                            }

                            // 清理资源
                            let _ = video.send_eof();
                        }
                    }
                }
            }

            let mut audio_codec = None;
            let mut audio_bitrate = None;
            let mut audio_rate = None;
            if let Some(stream) = ictx.streams().best(ffmpeg::media::Type::Audio) {
                if let Ok(context) = ffmpeg::codec::context::Context::from_parameters(stream.parameters()) {
                    audio_codec.replace(context.id().name().to_string());
                    if let Ok(audio) = context.decoder().audio() {
                        audio_bitrate.replace(audio.bit_rate());
                        audio_rate.replace(audio.rate());
                    }
                }
            }

            let meta = VideoMetadata {
                duration,
                width,
                height,
                video_codec,
                video_bitrate,
                audio_codec,
                audio_bitrate,
                audio_rate,
                image_name,
            };
            return Some(meta);
        }
        Err(_e) => {}
    }
    None
}
fn save_frame_as_image(frame: &ffmpeg::frame::Video, path: impl AsRef<Path>) -> anyhow::Result<()> {
    // 使用 image crate 保存为 PNG
    let img = image::RgbImage::from_raw(
        frame.width(),
        frame.height(),
        frame.data(0).to_vec()
    ).unwrap();

    match img.save(path) {
        Ok(_) => Ok(()),
        Err(e) => anyhow::bail!("{:?}", e)
    }

}
