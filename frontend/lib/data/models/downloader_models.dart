class DownloaderRequest {
  final String url;
  final bool extractAudioOnly;
  final bool cropWatermarkBars;
  final String maxResolution;

  DownloaderRequest({
    required this.url,
    this.extractAudioOnly = false,
    this.cropWatermarkBars = false,
    this.maxResolution = '1080p',
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'extract_audio_only': extractAudioOnly,
      'crop_watermark_bars': cropWatermarkBars,
      'max_resolution': maxResolution,
    };
  }
}
