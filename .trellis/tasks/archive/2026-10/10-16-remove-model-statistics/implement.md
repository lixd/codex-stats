# Execution

1. Root先更新正式需求/设计，保存before哈希；review边界后启动任务。
2. trellis-implement负责DashboardView.swift与必要UIPreview/preview脚本删除；不改Core/Store/其他页面；自验后冻结Sources/Tests/Scripts并通知root。
3. trellis-check独立审查删除范围/孤儿引用/四页与保留功能，最终typecheck；root检查原生代表截图并运行必要门禁，不重复未变Core全套。
4. Root更新v0.2.19/build21，冻结输入后优化独立构建/签名、记录证据、同步基线、归档/记journal均no-commit，打App与源码ZIP并校验字节。
