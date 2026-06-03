import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:harbor_visible_kit/app/state/locale_store.dart';
import 'package:harbor_visible_kit/app/state/theme_store.dart';
import 'package:harbor_visible_kit/domain/artifacts/artifact_kind_classifier.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';

class AppStrings {
  final AppLanguage appLanguage;

  const AppStrings(this.appLanguage);

  static const fallback = AppStrings(AppLanguage.zhHans);
  static const delegate = _AppStringsDelegate();
  static const supportedLocales = <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale('en'),
  ];

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ?? fallback;
  }

  bool get isEnglish => appLanguage == AppLanguage.en;

  String pick(String zhHans, String en) => isEnglish ? en : zhHans;

  String plural(int count, String singular, String plural) {
    return count == 1 ? singular : plural;
  }

  String get appName => 'Harbor Visible Kit';
  String get appSubtitle => pick('Harbor 工具', 'Harbor tools');
  String get connected => pick('已连接', 'Connected');
  String get disconnected => pick('未连接', 'Disconnected');
  String get close => pick('关闭', 'Close');
  String get cancel => pick('取消', 'Cancel');
  String get confirm => pick('确定', 'OK');
  String get clear => pick('清空', 'Clear');
  String get select => pick('选择', 'Choose');
  String get save => pick('保存', 'Save');
  String get refresh => pick('刷新', 'Refresh');
  String get processing => pick('正在处理', 'Processing');
  String get expandSelect => pick('展开选择', 'Open selector');
  String get noOptions => pick('当前没有可选项', 'No options available');

  String get navConnection => pick('连接配置', 'Connection');
  String get navPush => pick('推送制品', 'Push artifacts');
  String get navPull => pick('提取制品', 'Pull artifacts');
  String get navSettings => pick('设置', 'Settings');
  String get pressEnterToOpen => pick('按 Enter 打开', 'Press Enter to open');
  String harborConnected(String registry) =>
      pick('Harbor 已连接，$registry', 'Harbor connected, $registry');
  String get harborDisconnected => pick('Harbor 未连接', 'Harbor disconnected');

  String get settingsTitle => pick('设置', 'Settings');
  String get settingsDescription => pick(
    '管理界面主题、应用语言、应用标识与版本信息',
    'Manage theme, language, app identity, and version',
  );
  String get appearance => pick('外观', 'Appearance');
  String get language => pick('语言', 'Language');
  String get about => pick('关于', 'About');
  String get versionInfo => pick('版本信息：v1.0.0', 'Version: v1.0.0');
  String get zhHansLanguage => '简体中文';
  String get englishLanguage => 'English';

  String themeModeLabel(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => pick('跟随系统', 'System'),
      AppThemeMode.light => pick('浅色', 'Light'),
      AppThemeMode.dark => pick('深色', 'Dark'),
    };
  }

  String languageLabel(AppLanguage value) {
    return switch (value) {
      AppLanguage.zhHans => zhHansLanguage,
      AppLanguage.en => englishLanguage,
    };
  }

  String templateName(String value) {
    if (value == '默认配置') return pick('默认配置', 'Default config');
    return value;
  }

  String artifactLabel(PushArtifactType type) {
    return switch (type) {
      PushArtifactType.jar => pick('JAR 服务包', 'JAR service package'),
      PushArtifactType.image => pick('Docker 镜像包', 'Docker image archive'),
      PushArtifactType.web => pick('Web 前端包', 'Web frontend package'),
      PushArtifactType.apk => 'Android APK',
    };
  }

  String artifactShortLabel(PushArtifactType type) {
    return switch (type) {
      PushArtifactType.jar => 'JAR',
      PushArtifactType.image => pick('镜像', 'Image'),
      PushArtifactType.web => 'Web',
      PushArtifactType.apk => 'APK',
    };
  }

  String acceptedFileDescription(PushArtifactType type) {
    return switch (type) {
      PushArtifactType.jar => pick('仅支持 .jar', 'Only .jar files'),
      PushArtifactType.image => pick(
        '仅支持 .tar.gz / .tgz / .tar',
        'Only .tar.gz / .tgz / .tar files',
      ),
      PushArtifactType.web => pick('仅支持 dist.zip', 'Only dist.zip'),
      PushArtifactType.apk => pick(
        '仅支持 .apk，可选命名: 应用名 V版本 build构建号.apk',
        'Only .apk files. Optional naming: AppName Vversion buildNumber.apk',
      ),
    };
  }

  String kindLabelForRepositoryName(String repositoryName) {
    final label = ArtifactKindClassifier.kindLabelForRepositoryName(
      repositoryName,
    );
    if (label == '镜像') return pick('镜像', 'Image');
    return label;
  }

  String targetError(String error) {
    if (!isEnglish) return error;
    final exact = <String, String>{
      '请先连接 Harbor': 'Please connect to Harbor first',
      '请选择项目空间': 'Please select a project namespace',
      '请填写版本标签': 'Please enter a version tag',
      '标签后缀仅支持 ASCII 字母、数字、下划线、中划线和点号':
          'Tag suffix only supports ASCII letters, numbers, underscores, hyphens, and dots',
      '无法从文件名识别仓库名，请手动填写仓库名':
          'Could not infer a repository name from the file name. Enter it manually',
      '无法推导版本标签': 'Could not infer a version tag',
      '最终标签包含 Docker 不支持的字符':
          'The final tag contains characters Docker does not support',
      'JAR 服务包批次只能选择 .jar 文件':
          'JAR service package batches only support .jar files',
      'Docker 镜像包批次只能选择 .tar.gz/.tgz/.tar 文件':
          'Docker image archive batches only support .tar.gz/.tgz/.tar files',
      'Web 前端包批次只能选择 dist.zip 文件':
          'Web frontend package batches only support dist.zip',
      'Android APK 批次只能选择 .apk 文件':
          'Android APK batches only support .apk files',
    };
    final translated = exact[error];
    if (translated != null) return translated;

    final apkMismatch = RegExp(
      r'^APK 文件版本 (.+) 与当前版本标签 (.+) 不一致，请选择正确包或修改版本标签$',
    ).firstMatch(error);
    if (apkMismatch != null) {
      return 'APK file version ${apkMismatch.group(1)} does not match the current version tag ${apkMismatch.group(2)}. Choose the correct package or update the version tag';
    }

    final fileMismatch = RegExp(
      r'^文件版本 (.+) 与当前版本标签 (.+) 不一致，请选择正确包或修改版本标签$',
    ).firstMatch(error);
    if (fileMismatch != null) {
      return 'File version ${fileMismatch.group(1)} does not match the current version tag ${fileMismatch.group(2)}. Choose the correct package or update the version tag';
    }

    return error;
  }

  String errorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return runtimeMessage(message);
  }

  String runtimeMessage(String message) {
    if (!isEnglish) return message;

    final targetTranslated = targetError(message);
    if (targetTranslated != message) return targetTranslated;

    final exact = <String, String>{
      '连接超时，请检查 IP 和端口是否正确':
          'Connection timed out. Check that the IP and port are correct',
      '认证失败，请检查用户名和密码':
          'Authentication failed. Check the username and password',
      'Harbor API 未配置，请先设置连接信息':
          'Harbor API is not configured. Set connection information first',
      'Web 前端包文件必须命名为 dist.zip':
          'The Web frontend package file must be named dist.zip',
      '正在解析镜像包...': 'Parsing image archive...',
      '正在上传镜像 config': 'Uploading image config',
      '正在生成本地镜像归档...': 'Generating local image archive...',
      '镜像清单缺少 config 描述': 'Image manifest is missing a config descriptor',
      '镜像清单中存在缺少 digest 的 layer':
          'Image manifest contains a layer without digest',
      '多架构镜像清单缺少 digest': 'Multi-arch image manifest is missing digest',
      '多架构镜像清单为空': 'Multi-arch image manifest is empty',
      '暂不支持 zstd 压缩 layer': 'zstd-compressed layers are not supported yet',
    };
    final translated = exact[message];
    if (translated != null) return translated;

    for (final pattern in _runtimePatterns) {
      final match = pattern.regex.firstMatch(message);
      if (match != null) return pattern.translate(match, this);
    }

    return message;
  }

  String englishArtifactTerm(String value) {
    return value
        .replaceAll('JAR 制品', 'JAR artifact')
        .replaceAll('Web 前端包', 'Web frontend package')
        .replaceAll('镜像归档', 'image archive')
        .replaceAll('镜像包', 'image archive')
        .replaceAll('镜像', 'image');
  }
}

class _RuntimeMessagePattern {
  final RegExp regex;
  final String Function(RegExpMatch match, AppStrings strings) translate;

  const _RuntimeMessagePattern(this.regex, this.translate);
}

final _runtimePatterns = <_RuntimeMessagePattern>[
  _RuntimeMessagePattern(
    RegExp(r'^连接失败: (.+)$'),
    (match, _) => 'Connection failed: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^认证失败: (.+)$'),
    (match, _) => 'Authentication failed: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^获取项目列表失败: (.+)$'),
    (match, _) => 'Failed to get project list: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^创建项目空间失败: (.+)$'),
    (match, _) => 'Failed to create project namespace: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^获取仓库列表失败: (.+)$'),
    (match, _) => 'Failed to get repository list: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^获取制品列表失败: (.+)$'),
    (match, _) => 'Failed to get artifact list: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^获取版本标签失败: (.+)$'),
    (match, _) => 'Failed to get version tags: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^(.+) 文件必须是 \.apk 安装包$'),
    (match, strings) =>
        '${strings.englishArtifactTerm(match.group(1)!)} file must be an .apk package',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^(.+) 文件内容为空: (.+)$'),
    (match, strings) =>
        '${strings.englishArtifactTerm(match.group(1)!)} file is empty: ${match.group(2)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^读取 tar 归档失败: (.+)$'),
    (match, _) => 'Failed to read tar archive: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^已上传 blob (.+)$'),
    (match, _) => 'Uploaded blob ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^正在构造 (.+) 镜像: (.+)$'),
    (match, strings) =>
        'Building ${strings.englishArtifactTerm(match.group(1)!)} image: ${match.group(2)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^(.+) 上传完成: (.+)$'),
    (match, strings) =>
        '${strings.englishArtifactTerm(match.group(1)!)} upload completed: ${match.group(2)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^正在上传 OCI blob (.+)$'),
    (match, _) => 'Uploading OCI blob ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^OCI 镜像包上传完成: (.+)$'),
    (match, _) => 'OCI image archive uploaded: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^正在上传 layer (.+)$'),
    (match, _) => 'Uploading layer ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^镜像包上传完成: (.+)$'),
    (match, _) => 'Image archive uploaded: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^正在下载 (.+) 镜像清单: (.+)$'),
    (match, strings) =>
        'Downloading ${strings.englishArtifactTerm(match.group(1)!)} image manifest: ${match.group(2)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^正在下载 layer (.+)$'),
    (match, _) => 'Downloading layer ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^(.+) 已保存到: (.+)$'),
    (match, strings) =>
        '${strings.englishArtifactTerm(match.group(1)!)} saved to: ${match.group(2)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^正在下载镜像清单: (.+)$'),
    (match, _) => 'Downloading image manifest: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^镜像归档已保存到: (.+)$'),
    (match, _) => 'Image archive saved to: ${match.group(1)}',
  ),
  _RuntimeMessagePattern(
    RegExp(r'^镜像中未找到 (.+)$'),
    (match, _) => 'Not found in image: ${match.group(1)}',
  ),
];

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'zh' || locale.languageCode == 'en';
  }

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture(AppStrings(AppLanguage.fromLocale(locale)));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

extension AppStringsBuildContext on BuildContext {
  AppStrings get l10n => AppStrings.of(this);

  String t(String zhHans, String en) => AppStrings.of(this).pick(zhHans, en);
}
