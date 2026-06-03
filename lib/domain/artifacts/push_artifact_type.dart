enum PushArtifactType {
  jar,
  image,
  web,
  apk;

  static PushArtifactType fromName(String? name) {
    return switch (name) {
      'damengImage' => PushArtifactType.image,
      'androidAppA' || 'androidAppB' => PushArtifactType.apk,
      _ => PushArtifactType.values.firstWhere(
        (type) => type.name == name,
        orElse: () => PushArtifactType.jar,
      ),
    };
  }

  String get label {
    return switch (this) {
      PushArtifactType.jar => 'JAR 服务包',
      PushArtifactType.image => 'Docker 镜像包',
      PushArtifactType.web => 'Web 前端包',
      PushArtifactType.apk => 'Android APK',
    };
  }

  String get shortLabel {
    return switch (this) {
      PushArtifactType.jar => 'JAR',
      PushArtifactType.image => '镜像',
      PushArtifactType.web => 'Web',
      PushArtifactType.apk => 'APK',
    };
  }

  List<String> get allowedExtensions {
    return switch (this) {
      PushArtifactType.jar => const ['jar'],
      PushArtifactType.image => const ['tar.gz', 'tgz', 'tar'],
      PushArtifactType.web => const ['zip'],
      PushArtifactType.apk => const ['apk'],
    };
  }

  String get acceptedFileDescription {
    return switch (this) {
      PushArtifactType.jar => '仅支持 .jar',
      PushArtifactType.image => '仅支持 .tar.gz / .tgz / .tar',
      PushArtifactType.web => '仅支持 dist.zip',
      PushArtifactType.apk => '仅支持 .apk，可选命名: 应用名 V版本 build构建号.apk',
    };
  }
}
