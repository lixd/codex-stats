# Publication design
先更新仓库设计：用户确认 public+MIT。根LICENSE采用GitHub licenses API的MIT正文，2026 lixd；THIRD_PARTY_NOTICES说明独立Trellis工具及生成模板仍AGPL，并保留上游完整license于licenses。App构建仅Sources与系统framework，不链接开发工具。
检查ignore、拟提交内容、敏感字段、绝对用户路径；仅发现跨平台通用路径示例，不需要删通用工具注释。同步README/CONTRIBUTING过去待选协议/无远端状态。
初始commit包括共享源/文档/测试/必要workflow，排除私人工作状态。先审查与测试，再gh repo create --public、git push origin main；失败不伪装发布成功。
