import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  late TextEditingController _geminiKeyCtrl;
  late TextEditingController _geminiModelCtrl;
  late TextEditingController _geminiBaseUrlCtrl;

  late TextEditingController _deepseekKeyCtrl;
  late TextEditingController _deepseekModelCtrl;
  late TextEditingController _deepseekBaseUrlCtrl;

  late TextEditingController _openaiKeyCtrl;
  late TextEditingController _openaiModelCtrl;
  late TextEditingController _openaiBaseUrlCtrl;

  late TextEditingController _customKeyCtrl;
  late TextEditingController _customModelCtrl;
  late TextEditingController _customBaseUrlCtrl;

  late TextEditingController _ocrSpaceKeyCtrl;
  late TextEditingController _systemPromptCtrl;

  @override
  void initState() {
    super.initState();
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    _geminiKeyCtrl = TextEditingController(text: s.geminiApiKey);
    _geminiModelCtrl = TextEditingController(text: s.geminiModel);
    _geminiBaseUrlCtrl = TextEditingController(text: s.geminiBaseUrl);

    _deepseekKeyCtrl = TextEditingController(text: s.deepSeekApiKey);
    _deepseekModelCtrl = TextEditingController(text: s.deepSeekModel);
    _deepseekBaseUrlCtrl = TextEditingController(text: s.deepSeekBaseUrl);

    _openaiKeyCtrl = TextEditingController(text: s.openAiApiKey);
    _openaiModelCtrl = TextEditingController(text: s.openAiModel);
    _openaiBaseUrlCtrl = TextEditingController(text: s.openAiBaseUrl);

    _customKeyCtrl = TextEditingController(text: s.customApiKey);
    _customModelCtrl = TextEditingController(text: s.customModel);
    _customBaseUrlCtrl = TextEditingController(text: s.customBaseUrl);

    _ocrSpaceKeyCtrl = TextEditingController(text: s.ocrSpaceApiKey);
    _systemPromptCtrl = TextEditingController(text: s.customSystemPrompt);
  }

  @override
  void dispose() {
    _geminiKeyCtrl.dispose();
    _geminiModelCtrl.dispose();
    _geminiBaseUrlCtrl.dispose();
    _deepseekKeyCtrl.dispose();
    _deepseekModelCtrl.dispose();
    _deepseekBaseUrlCtrl.dispose();
    _openaiKeyCtrl.dispose();
    _openaiModelCtrl.dispose();
    _openaiBaseUrlCtrl.dispose();
    _customKeyCtrl.dispose();
    _customModelCtrl.dispose();
    _customBaseUrlCtrl.dispose();
    _ocrSpaceKeyCtrl.dispose();
    _systemPromptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SettingsProvider>(context);
    final s = prov.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('高级功能与深度配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _saveAll(prov),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. OCR 引擎选择与高级参数
          const Text('1. OCR 识别引擎选择', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: s.ocrEngine,
                    decoration: const InputDecoration(labelText: '当前生效的 OCR 引擎'),
                    items: const [
                      DropdownMenuItem(
                        value: 'gemini_vision',
                        child: Text('Gemini 视觉多模态直出 (推荐默认, 免费)'),
                      ),
                      DropdownMenuItem(
                        value: 'ocr_space',
                        child: Text('OCR.space 免费在线 API (中英文支持)'),
                      ),
                      DropdownMenuItem(
                        value: 'mlkit_local',
                        child: Text('端侧离线 ML Kit OCR 引擎 (零流量)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) prov.updatePartial(ocrEngine: val);
                    },
                  ),
                  if (s.ocrEngine == 'ocr_space') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ocrSpaceKeyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'OCR.space API Key',
                        hintText: '默认使用公共免费 Key，可填入自己的 Key',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('图像自动旋转与方向矫正', style: TextStyle(fontSize: 14)),
                    value: s.ocrAutoRotate,
                    onChanged: (val) {
                      s.ocrAutoRotate = val;
                      prov.updateSettings(s);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('图像自动对比度增强去噪', style: TextStyle(fontSize: 14)),
                    value: s.ocrPreprocess,
                    onChanged: (val) {
                      s.ocrPreprocess = val;
                      prov.updateSettings(s);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. AI 大模型提供商与参数选择
          const Text('2. AI 大模型提供商与接入配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: s.aiProvider,
                    decoration: const InputDecoration(labelText: '默认 AI 大模型厂商'),
                    items: const [
                      DropdownMenuItem(value: 'gemini', child: Text('Google Gemini (默认 gemini-3.7-flash)')),
                      DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek (深度求索 V3/R1)')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI (GPT-4o / 4o-mini)')),
                      DropdownMenuItem(value: 'custom', child: Text('自定义兼容 OpenAI 协议 (Ollama/硅基流动等)')),
                    ],
                    onChanged: (val) {
                      if (val != null) prov.updatePartial(aiProvider: val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Gemini 配置项
                  if (s.aiProvider == 'gemini') ...[
                    TextField(
                      controller: _geminiKeyCtrl,
                      decoration: const InputDecoration(labelText: 'Gemini API Key *', hintText: 'AIzaSy...'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _geminiModelCtrl,
                      decoration: const InputDecoration(labelText: '模型名称 (默认 gemini-3.7-flash)', hintText: 'gemini-3.7-flash'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _geminiBaseUrlCtrl,
                      decoration: const InputDecoration(labelText: 'Gemini Base URL', hintText: 'https://generativelanguage.googleapis.com'),
                    ),
                  ],

                  // DeepSeek 配置项
                  if (s.aiProvider == 'deepseek') ...[
                    TextField(
                      controller: _deepseekKeyCtrl,
                      decoration: const InputDecoration(labelText: 'DeepSeek API Key *', hintText: 'sk-...'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deepseekModelCtrl,
                      decoration: const InputDecoration(labelText: '模型名称 (默认 deepseek-chat)', hintText: 'deepseek-chat'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deepseekBaseUrlCtrl,
                      decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://api.deepseek.com/v1'),
                    ),
                  ],

                  // OpenAI 配置项
                  if (s.aiProvider == 'openai') ...[
                    TextField(
                      controller: _openaiKeyCtrl,
                      decoration: const InputDecoration(labelText: 'OpenAI API Key *', hintText: 'sk-...'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _openaiModelCtrl,
                      decoration: const InputDecoration(labelText: '模型名称', hintText: 'gpt-4o'),
                    ),
                  ],

                  // Custom 配置项
                  if (s.aiProvider == 'custom') ...[
                    TextField(
                      controller: _customBaseUrlCtrl,
                      decoration: const InputDecoration(labelText: '自定义 Base URL (兼容 /v1/chat/completions)', hintText: 'https://api.siliconflow.cn/v1'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customKeyCtrl,
                      decoration: const InputDecoration(labelText: '自定义 API Key', hintText: 'sk-...'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customModelCtrl,
                      decoration: const InputDecoration(labelText: '自定义 Model 名称', hintText: 'deepseek-ai/DeepSeek-V3'),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('温度 (Temperature): '),
                      Expanded(
                        child: Slider(
                          value: s.aiTemperature,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: s.aiTemperature.toStringAsFixed(1),
                          onChanged: (val) {
                            s.aiTemperature = val;
                            prov.updateSettings(s);
                          },
                        ),
                      ),
                      Text(s.aiTemperature.toStringAsFixed(1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. 性能与安全
          const Text('3. 隐私保护与性能调节', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('指纹 / 面容生物识别解锁', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('每次进入 App 时要求验证生物特征以保护隐私'),
                  value: s.enableBiometricLock,
                  onChanged: (val) {
                    s.enableBiometricLock = val;
                    prov.updateSettings(s);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('开启详细调试日志', style: TextStyle(fontSize: 14)),
                  value: s.enableDebugLogs,
                  onChanged: (val) {
                    s.enableDebugLogs = val;
                    prov.updateSettings(s);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _saveAll(SettingsProvider prov) {
    final s = prov.settings;
    s.geminiApiKey = _geminiKeyCtrl.text.trim();
    s.geminiModel = _geminiModelCtrl.text.trim();
    s.geminiBaseUrl = _geminiBaseUrlCtrl.text.trim();

    s.deepSeekApiKey = _deepseekKeyCtrl.text.trim();
    s.deepSeekModel = _deepseekModelCtrl.text.trim();
    s.deepSeekBaseUrl = _deepseekBaseUrlCtrl.text.trim();

    s.openAiApiKey = _openaiKeyCtrl.text.trim();
    s.openAiModel = _openaiModelCtrl.text.trim();
    s.openAiBaseUrl = _openaiBaseUrlCtrl.text.trim();

    s.customApiKey = _customKeyCtrl.text.trim();
    s.customModel = _customModelCtrl.text.trim();
    s.customBaseUrl = _customBaseUrlCtrl.text.trim();

    s.ocrSpaceApiKey = _ocrSpaceKeyCtrl.text.trim();
    s.customSystemPrompt = _systemPromptCtrl.text.trim();

    prov.updateSettings(s);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('高级设置已保存！')),
    );
    Navigator.pop(context);
  }
}
