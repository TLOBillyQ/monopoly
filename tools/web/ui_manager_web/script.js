
class UINodesMerger {
    constructor() {
        this.data = {};
        this.init();
    }

    init() {
        this.bindEvents();
    }

    bindEvents() {
        const fileInput = document.getElementById('fileInput');
        const fileInputArea = document.getElementById('fileInputArea');
        const processBtn = document.getElementById('processBtn');
        const clearBtn = document.getElementById('clearBtn');
        const copyBtn = document.getElementById('copyBtn');
        const downloadBtn = document.getElementById('downloadBtn');

        // 文件拖拽
        fileInputArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            fileInputArea.classList.add('dragover');
        });

        fileInputArea.addEventListener('dragleave', () => {
            fileInputArea.classList.remove('dragover');
        });

        fileInputArea.addEventListener('drop', (e) => {
            e.preventDefault();
            fileInputArea.classList.remove('dragover');
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                this.handleFile(files[0]);
            }
        });

        // 文件选择
        fileInput.addEventListener('change', () => {
            if (fileInput.files.length > 0) {
                this.handleFile(fileInput.files[0]);
            }
        });

        // 按钮事件
        processBtn.addEventListener('click', () => this.processData());
        clearBtn.addEventListener('click', () => this.clearAll());
        copyBtn.addEventListener('click', () => this.copyToClipboard());
        downloadBtn.addEventListener('click', () => this.downloadFile());
    }

    handleFile(file) {
        const reader = new FileReader();
        reader.onload = (e) => {
            document.getElementById('inputText').value = e.target.result;
            this.showMessage('文件加载成功！', 'success');
        };
        reader.onerror = () => {
            this.showMessage('文件读取失败，请重试。', 'error');
        };
        reader.readAsText(file, 'utf-8');
    }

    processData() {
        const inputText = document.getElementById('inputText').value.trim();
        if (!inputText) {
            this.showMessage('请先输入或选择文件内容。', 'error');
            return;
        }

        try {
            this.parseInput(inputText);
            this.generateOutput();
            this.showMessage('数据处理完成！', 'success');
        } catch (error) {
            this.showMessage('处理数据时出错：' + error.message, 'error');
        }
    }

    parseInput(inputText) {
        this.data = {};
        const lines = inputText.split('\n');

        for (let line of lines) {
            line = line.trim();

            // 解析有效行 (包括注释的行)
            const match = line.match(/^\s*(?:--\s*)?(?:\["([^"]+)"\]|(\w+))\s*=\s*"([^"]+)"\s*--\[\[@as\s+(\w+)\]\]/);
            if (match) {
                const [, eng_name, name, id, type] = match;
                const key = eng_name || name;


                // 以ID为键，名称和类型为值
                this.data[id] = { key, type };
            }
        }
    }

    generateOutput() {
        let output = '---AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT\n\nreturn {\n';

        // 按ID排序
        const sortedIds = Object.keys(this.data).sort();

        for (let i = 0; i < sortedIds.length; i++) {
            const id = sortedIds[i];
            const item = this.data[id];

            // 格式: ["ID"] = {"名称", "类型"}
            output += `\t["${id}"] = {"${item.key}", "${item.type}"},\n`;
        }

        // 新增 length 字段
        output += `\t--length = ${sortedIds.length}\n`;
        output += '}';
        document.getElementById('outputText').value = output;
    }

    copyToClipboard() {
        const outputText = document.getElementById('outputText');
        outputText.select();
        document.execCommand('copy');
        this.showMessage('已复制到剪贴板！', 'success');
    }

    downloadFile() {
        const content = document.getElementById('outputText').value;
        const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = 'UINodes_merged.lua';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        this.showMessage('文件下载已开始！', 'success');
    }

    clearAll() {
        document.getElementById('inputText').value = '';
        document.getElementById('outputText').value = '';
        document.getElementById('fileInput').value = '';
        this.data = {};
        this.showMessage('已清空所有内容！', 'success');
    }

    showMessage(message, type) {
        // 移除现有消息
        document.querySelectorAll('.error-message, .success-message').forEach(el => el.remove());

        const messageDiv = document.createElement('div');
        messageDiv.className = type === 'error' ? 'error-message' : 'success-message';
        messageDiv.textContent = message;

        const mainContent = document.querySelector('.main-content');
        mainContent.insertBefore(messageDiv, mainContent.firstChild);

        // 3秒后自动移除
        setTimeout(() => {
            if (messageDiv.parentNode) {
                messageDiv.remove();
            }
        }, 3000);
    }
}

// 初始化应用
document.addEventListener('DOMContentLoaded', () => {
    new UINodesMerger();
});