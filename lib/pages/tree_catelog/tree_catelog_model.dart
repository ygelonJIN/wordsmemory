import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'tree_catelog_widget.dart' show TreeCatelogWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

/// 单个词根组（如 A、C、D、R、T）
class TreeGroupModel {
  final String groupName;
  final List<TreeRootDisplayModel> roots;

  TreeGroupModel({required this.groupName, required this.roots});
}

class TreeCatelogModel extends FlutterFlowModel<TreeCatelogWidget> {
  /// 分组后的词根目录数据
  List<TreeGroupModel> groups = [];

  /// 每个分组内部的词根列表（按 group 分组）
  /// groups[index].roots[y]  <==>  _flatRoots[index * ? + y]
  /// 便于 widget 快速定位 rootId 而无需遍历嵌套结构
  List<TreeRootDisplayModel> flatRoots = [];

  bool isLoading = true;
  bool _disposed = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
  }

  @override
  void onInitialized() {
    _loadData();
  }

  /// 从 BackendManager 加载分组词根数据
  Future<void> _loadData() async {
    if (_disposed) return;
    final ctx = context;
    if (ctx == null) return;

    try {
      final groupNames = await BackendManager.instance.treeManager.getAllGroups();

      final loadedGroups = <TreeGroupModel>[];
      final loadedFlatRoots = <TreeRootDisplayModel>[];

      for (final group in groupNames) {
        final roots = await BackendManager.instance.loadTreeRootsForGroup(group);

        loadedGroups.add(TreeGroupModel(
          groupName: group,
          roots: roots,
        ));

        loadedFlatRoots.addAll(roots);
      }

      if (!_disposed) {
        updatePage(() {
          groups = loadedGroups;
          flatRoots = loadedFlatRoots;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!_disposed) {
        updatePage(() => isLoading = false);
        ctx.pushNamed(ErrorPageWidget.routeName);
      }
    }
  }

  /// 根据 flat index 定位到第几个 group 及该 group 内的 index
  /// 返回 (groupIndex, rootIndexWithinGroup)
  (int, int)? resolveFlatIndex(int flatIndex) {
    if (flatIndex < 0 || flatIndex >= flatRoots.length) return null;

    int acc = 0;
    for (int gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      if (flatIndex < acc + group.roots.length) {
        return (gi, flatIndex - acc);
      }
      acc += group.roots.length;
    }
    return null;
  }

  /// 导航到指定词根的结构树详情页
  void navigateToRoot(String rootId) {
    context?.go('/treePage?rootId=$rootId');
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
