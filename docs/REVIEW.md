# 独立审查及缺陷关闭记录

依据 `DEMO_AGENT_PROMPT.txt`。日期：2026-10-29。此报告区分实际复现、修复后执行与尚未覆盖的产品验收。初始问题原文保存在 `docs/evidence/review_initial.md`、`review_pre_delivery.md`；原始失败 JSON/日志保留为 `*_before_fix.*`。没有用后续 PASS 删除历史 FAIL。

## 已关闭的可复现问题

| 问题 | 修复与实际复证 | 结论 |
|---|---|---|
| 培训后工人减少而已就业数未同步，正常存档无法读取 | `_reconcile_jobs` 同步岗位；`simulation_review_probe.json` 正常正式 act 路径存读成功、规范状态相同，继续15天完整状态一致，双方 audit 均为空。 | CLOSED，正常操作回归 |
| 远征迁移后源据点就业超过劳动力 | `outpost_jobs_review.json` 源工人44→26时岗位38→26，audit为空，当日立即保存读取成功。 | CLOSED，正常操作回归 |
| 劳动力不足时被拒绝的远征仍扣款 | `simulation_review_probe.json` 报告错误后完整状态不变；正式95项测试同样覆盖。 | CLOSED，失败动作原子性 |
| 民营企业绕过24座土地上限 | `_enterprise` 在投资前检查容量；`enterprise_capacity_review.json` 保持24座并报明确原因，完整状态不变。 | CLOSED，受控容量夹具；非手工建设24座 |
| 孤岛首府造成合同永久不可达 | `_settle` 首次登陆前要求存在另一可达候选地；`island_start_review.json` 拒绝孤岛后仍能正常建立0、1两个据点。 | CLOSED，正式 act 路径 |
| 河道逆坡、地区无道路出口、17–24设施槽位重复、企业重复建筑、连接后地区未刷新 | `world_review_probe_CC-GEO-1.4.json` 的6种子数据探针、`world_support_independent.log` 与最终世界报告记录修复。 | CLOSED，数据/场景支持范围；视觉另验 |
| 事件日志直接显示内部字典 | `VISUAL_QA.md` 实际查看最终三分辨率事件图，均为中文日期与消息。 | CLOSED，所查看样本 |

## 交付收尾发现并修复：损坏嵌套存档污染当前局

初始复现把完整存档的 `settlements[0].stock` 从字典改为整数5，并重新计算精确快照校验值。旧读取函数先访问 `stock.has()`，触发GDScript运行时错误；错误并不以异常传播给调用方，随后审计也出错，最终 `load_game()` 仍返回空字符串，并替换了当前状态。`save_nested_type_review_before_fix.json/.log` 保留这一实际 FAIL。它是人为构造损坏档的容错缺陷，不是把正常玩家存档无法保存的旧问题再次计数。

修复仅改变载入验证：访问内部字段之前检查容器、必需字段、数值类型与有限值、世界格网尺寸、货物资源/坐标和人口非负；验证不通过则返回具体错误，不进入状态替换。经营数值、生产、合同和世界规则未修改。外层版本也先验证类型再比较。

实际验证：

- 原探针 `tools/review_save_nested_type.gd` 再运行退出0，返回“存档字段类型无效：settlement.stock”，`state_unchanged=true`，无 SCRIPT ERROR。结果 `save_nested_type_review.json/.log`。
- 新探针 `tools/review_save_nested_regressions.gd` 共21项全部通过：18类重新计算校验值的损坏内部字段被拒绝且当前状态字节不变；另验证交付中期档、旧UI第50日档、含待处理事件的精确存读。结果 `save_nested_regressions.json/.log`。
- 正式 `res://tests/sim_tests.gd` 修复后再跑 **95项PASS、0FAIL、退出码0**。三优势180日回放的成功日、余额、税收与修复前一致；日志 `evidence/sim_save_validation_final.log`。
- 修复冻结源码 `game/simulation/sim.gd` SHA256：`35A0B6F1D249A36D7E7C2F665B59AF4AD8620B002B8FE4CA0096E23A0B664C73`。最终发行 EXE/PCK 由集成负责人重新导出，具体哈希以 VALIDATION/交付清单为准。

结论 **CLOSED（上述有界损坏档矩阵）**。这不是全面恶意文件模糊测试，也不是承诺所有自行改写且重新计算校验值的存档都符合游戏语义。正常存档完整一致性、失败加载不改当前局与人为构造攻击面应保持区分。

## 保留的验收边界

- 20–40分钟目标体验为 **PARTIAL**：自动正式路径35–38日履约，说明合同偏容易；脚本速度不能代替新玩家墙钟体验。
- 三种优势都有正式act自动生存/履约路径；不能据此写成三条人工完整试玩。
- 千万至亿级完整经济压力验证 **NOT_RUN**。汇总人口结构本身不等于大规模完整仿真证明。
- 地表采用低多边形工业沙盘；720p远景小标注与合同断行为非阻断改善项。三个分辨率与UI缩放的最新图形复证见 VISUAL_RELEASE_QA，而不是引用旧版截图替代新版。
- 最终保存退出重启、实际成功/失败、性能与打包验收统一由 `VALIDATION.md` 记录，不由本审查自动升级为通过。

后续CC-GEO-1.5兼容更新只放宽已支持的完整world版本至1.4/1.5，当前sim源码SHA256为7922C3157A57EBADFCAF314D0ED17216B2EA8C3D3DD5045F0B25143964821DC9；95项经营和21项存读在新1.5档上复跑通过，见evidence/sim_v15_final.log及docs/evidence/save_nested_regressions_v15.log。此前35A0B6F…为异常档修复时的1.4冻结身份，不是最终1.5源码哈希。
