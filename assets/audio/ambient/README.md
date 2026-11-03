# 环境录音

运行时使用三份单声道32 kHz Ogg Vorbis循环。海浪、海鸟来源为CC0，溪流为CC BY 3.0；完整署名、变更说明与链接见[CREDITS.txt](CREDITS.txt)，游戏设置内也可展开署名。

原始录音来自OpenGameArt的作者发布页，下载摘要与处理后文件摘要见[preparation.json](preparation.json)。`tools/build_ambient_audio.py --sources <原始文件目录>`可复现转换，需要ffmpeg（可通过`FFMPEG_BIN`指定）；不增加游戏运行依赖。原始下载仅保留在本机QA目录，项目内的运行时音频可直接使用。

声源位置与距离衰减由`scripts/city/spatial_ambience.gd`维护。城镇两个声源，山谷三个；听点跟随角色，海岸和溪流取最近水岸点，位置查询10 Hz。Ogg本身循环，距离超出max_distance由引擎停止混音；无每帧物理射线或大量重复解码器。室内另衰减12 dB，海鸟夜晚减弱，音量与静音沿用游戏设置。
