import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

void main() {
  runApp(const ImageViewerApp());
}

class ImageViewerApp extends StatelessWidget {
  const ImageViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Viewer',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ImageViewerHome(),
    );
  }
}

class ImageViewerHome extends StatefulWidget {
  const ImageViewerHome({super.key});

  @override
  State<ImageViewerHome> createState() => _ImageViewerHomeState();
}

class _ImageViewerHomeState extends State<ImageViewerHome> {
  List<File> imageFiles = [];
  String? selectedFolderPath;
  int currentImageIndex = 0;
  bool isLoading = false;
  bool isConcatenateView = false;
  bool isFullscreenMode = false;
  PageController pageController = PageController();

  // サポートされる画像拡張子
  final List<String> supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.tiff',
    '.tif',
    '.ico',
    '.svg',
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    if (Platform.isAndroid) {
      bool hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ストレージの権限が必要です。設定で権限を許可してください。'),
            action: SnackBarAction(
              label: '設定を開く',
              onPressed: () {
                openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _nextImage();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousImage();
          } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
            setState(() {
              isConcatenateView = !isConcatenateView;
            });
          } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
            setState(() {
              isFullscreenMode = !isFullscreenMode;
            });
          }
        }
      },
      child: Scaffold(
        appBar: isFullscreenMode
            ? null
            : AppBar(
                title: const Text('Image Viewer'),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                actions: [
                  if (imageFiles.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        isFullscreenMode
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                      ),
                      onPressed: () {
                        setState(() {
                          isFullscreenMode = !isFullscreenMode;
                        });
                      },
                      tooltip: isFullscreenMode ? 'フルスクリーン終了' : 'フルスクリーン',
                    ),
                  if (imageFiles.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        isConcatenateView
                            ? Icons.view_stream
                            : Icons.view_array,
                      ),
                      onPressed: () {
                        setState(() {
                          isConcatenateView = !isConcatenateView;
                        });
                      },
                      tooltip: isConcatenateView ? '通常表示' : '連結表示',
                    ),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: _pickFolder,
                    tooltip: 'フォルダを選択',
                  ),
                ],
              ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (imageFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'フォルダを選択して画像を表示',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              '※ Androidでは最初にストレージの権限を許可する必要があります',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              '操作: スワイプ・矢印キー・スペースキーで画像切り替え、Cキーで連結表示',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('フォルダを選択'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 画像情報とナビゲーション（フルスクリーンモード時は非表示）
        if (!isFullscreenMode)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${currentImageIndex + 1} / ${imageFiles.length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: currentImageIndex > 0 ? _previousImage : null,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton(
                      onPressed: currentImageIndex < imageFiles.length - 1
                          ? _nextImage
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // 画像表示（スワイプ対応と連結表示）
        Expanded(
          child: isConcatenateView ? _buildConcatenateView() : _buildPageView(),
        ),
        // ファイル名表示（フルスクリーンモード時は非表示）
        if (!isFullscreenMode)
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              path.basename(imageFiles[currentImageIndex].path),
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        // サムネイル一覧（フルスクリーンモード時は非表示）
        if (imageFiles.length > 1 && !isFullscreenMode)
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageFiles.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _setCurrentImage(index),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: index == currentImageIndex
                            ? Colors.blue
                            : Colors.grey.shade300,
                        width: index == currentImageIndex ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: index == currentImageIndex
                          ? [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.file(
                        imageFiles[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.error,
                                size: 20,
                                color: Colors.red,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // 通常のPageView表示
  Widget _buildPageView() {
    return PageView.builder(
      controller: pageController,
      itemCount: imageFiles.length,
      onPageChanged: (index) {
        setState(() {
          currentImageIndex = index;
        });
      },
      itemBuilder: (context, index) {
        return Container(
          width: double.infinity,
          padding: isFullscreenMode
              ? EdgeInsets.zero
              : const EdgeInsets.all(16),
          child: isFullscreenMode
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      isFullscreenMode = false;
                    });
                  },
                  child: InteractiveViewer(
                    child: Image.file(
                      imageFiles[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 50, color: Colors.red),
                              SizedBox(height: 10),
                              Text('画像を読み込めませんでした'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                )
              : InteractiveViewer(
                  child: Image.file(
                    imageFiles[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 50, color: Colors.red),
                            SizedBox(height: 10),
                            Text('画像を読み込めませんでした'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  // 連結表示（全画像を縦にスクロール）
  Widget _buildConcatenateView() {
    return InteractiveViewer(
      child: SingleChildScrollView(
        child: Column(
          children: imageFiles.asMap().entries.map((entry) {
            int index = entry.key;
            File imageFile = entry.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: index == currentImageIndex
                      ? Colors.blue
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    currentImageIndex = index;
                    isConcatenateView = false;
                  });
                },
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 50, color: Colors.red),
                            SizedBox(height: 10),
                            Text('画像を読み込めませんでした'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickFolder() async {
    try {
      setState(() {
        isLoading = true;
      });

      // 権限チェック
      if (Platform.isAndroid) {
        bool hasPermission = await _checkAndRequestPermissions();
        if (!hasPermission) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ストレージの権限が必要です')));
          return;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        selectedFolderPath = selectedDirectory;
        await _loadImagesFromFolder(selectedDirectory);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('フォルダの選択に失敗しました: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13以降の権限
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus manageExternalStorageStatus =
          await Permission.manageExternalStorage.status;

      // 権限が付与されていない場合は要求
      if (photosStatus != PermissionStatus.granted) {
        photosStatus = await Permission.photos.request();
      }

      if (storageStatus != PermissionStatus.granted) {
        storageStatus = await Permission.storage.request();
      }

      // Android 11以降では管理権限も必要な場合がある
      if (manageExternalStorageStatus != PermissionStatus.granted) {
        manageExternalStorageStatus = await Permission.manageExternalStorage
            .request();
      }

      return photosStatus == PermissionStatus.granted ||
          storageStatus == PermissionStatus.granted ||
          manageExternalStorageStatus == PermissionStatus.granted;
    }
    return true; // iOS やその他のプラットフォームでは true を返す
  }

  Future<void> _loadImagesFromFolder(String folderPath) async {
    try {
      final Directory directory = Directory(folderPath);

      // ディレクトリの存在確認
      if (!directory.existsSync()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('フォルダが見つかりません: $folderPath')));
        return;
      }

      imageFiles.clear();
      List<String> foundExtensions = [];

      // 再帰的にファイルを検索
      int totalFiles = await _searchImagesRecursively(
        directory,
        foundExtensions,
      );

      // ファイル名でソート（自然な順序）
      imageFiles.sort(
        (a, b) => _naturalSort(path.basename(a.path), path.basename(b.path)),
      );

      if (imageFiles.isNotEmpty) {
        currentImageIndex = 0;
        // PageControllerを初期化
        pageController = PageController(initialPage: 0);
      }

      setState(() {});

      // デバッグ情報を含むメッセージ
      if (imageFiles.isEmpty) {
        String debugInfo = 'フォルダ: $folderPath\n';
        debugInfo += '総ファイル数: $totalFiles\n';
        debugInfo += '見つかった拡張子: ${foundExtensions.join(', ')}\n';
        debugInfo += 'サポートされる拡張子: ${supportedExtensions.take(5).join(', ')}など';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像ファイルが見つかりませんでした\n$debugInfo'),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${imageFiles.length}個の画像ファイルを読み込みました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('画像の読み込みに失敗しました: $e')));
    }
  }

  Future<int> _searchImagesRecursively(
    Directory directory,
    List<String> foundExtensions,
  ) async {
    int totalFiles = 0;
    try {
      final List<FileSystemEntity> entities = directory.listSync();

      for (FileSystemEntity entity in entities) {
        if (entity is File) {
          totalFiles++;
          final String extension = path.extension(entity.path).toLowerCase();
          if (!foundExtensions.contains(extension) && extension.isNotEmpty) {
            foundExtensions.add(extension);
          }
          if (supportedExtensions.contains(extension)) {
            imageFiles.add(entity);
          }
        }
      }
    } catch (e) {
      // アクセス権限がないフォルダは無視
    }
    return totalFiles;
  }

  // 自然な順序でソート（数字を正しく処理）
  int _naturalSort(String a, String b) {
    // 先頭の空白を削除し、大文字小文字を統一
    a = a.trim();
    b = b.trim();

    // 正規表現で数字と文字列を分割
    RegExp regex = RegExp(r'(\d+|\D+)');
    List<String> partsA = regex.allMatches(a).map((m) => m.group(0)!).toList();
    List<String> partsB = regex.allMatches(b).map((m) => m.group(0)!).toList();

    int maxLength = partsA.length > partsB.length
        ? partsA.length
        : partsB.length;

    for (int i = 0; i < maxLength; i++) {
      // 一方が短い場合は、短い方を先にする
      if (i >= partsA.length) return -1;
      if (i >= partsB.length) return 1;

      String partA = partsA[i];
      String partB = partsB[i];

      // 両方が数字の場合、数値として比較
      if (_isNumeric(partA) && _isNumeric(partB)) {
        int numA = int.parse(partA);
        int numB = int.parse(partB);
        if (numA != numB) {
          return numA.compareTo(numB);
        }
      } else {
        // 文字列として比較（大文字小文字を区別しない）
        int comparison = partA.toLowerCase().compareTo(partB.toLowerCase());
        if (comparison != 0) {
          return comparison;
        }
      }
    }

    return 0;
  }

  // 文字列が数字のみかチェック
  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return RegExp(r'^\d+$').hasMatch(str);
  }

  void _nextImage() {
    if (currentImageIndex < imageFiles.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (currentImageIndex > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _setCurrentImage(int index) {
    if (index >= 0 && index < imageFiles.length) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
