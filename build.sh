#!/bin/bash

# --- 1. 配置 ---
COMP_DIR="components"
PAGES_DIR="pages"
SITE_DIR="site"
STATIC_DIR="$PAGES_DIR/static"

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 2. 初始化功能 ---
if [ "$1" = "init" ]; then
    mkdir -p "$COMP_DIR" "$PAGES_DIR/zh" "$STATIC_DIR"
    
    # 使用 cat <<EOF 确保生成的文件有良好的换行和缩进
    cat <<EOF > "$COMP_DIR/header.html"
<header>
    <h1>网站标题</h1>
    <nav>
        <a href="/">首页</a>
        <a href="/zh/about.html">关于</a>
    </nav>
</header>
EOF

    cat <<EOF > "$COMP_DIR/footer.html"
<footer>
    <p>&copy; 2023 静态网站构建器</p>
</footer>
EOF

    cat <<EOF > "$PAGES_DIR/index.html"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>首页</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    {{header}}
    <main>
        <h2>欢迎</h2>
        <p>这是一个超轻量的静态网站。</p>
        {{missing_example}}
    </main>
    {{footer}}
</body>
</html>
EOF

    cat <<EOF > "$STATIC_DIR/style.css"
body {
    font-family: sans-serif;
    line-height: 1.6;
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
    background: #f4f4f4;
}
header { border-bottom: 1px solid #ccc; padding-bottom: 10px; }
footer { margin-top: 20px; color: #666; font-size: 0.8em; }
EOF

    echo -e "${GREEN}项目已初始化。${NC}"
    # 以树状结构显示生成的目录
    find . -maxdepth 3 -not -path '*/.*' | sed -e "s/[^-][^\/]*\// |/g" -e "s/|\([^ ]\)/|-- \1/"
    
    echo -e "\n运行 ${YELLOW}./build.sh${NC} 进行构建。"
    exit 0
fi

# --- 3. 构建功能 ---
echo -e "${GREEN}开始构建...${NC}"

# A. 清理输出目录
rm -rf "$SITE_DIR" && mkdir -p "$SITE_DIR"

# B. 静态资源同步 (pages/static -> site/static)
if [ -d "$STATIC_DIR" ]; then
    cp -r "$STATIC_DIR" "$SITE_DIR/"
    echo "  已同步静态资源: static/"
fi

# C. 递归遍历页面
# 排除静态资源目录，只处理 .html 文件
find "$PAGES_DIR" -path "$STATIC_DIR" -prune -o -name "*.html" -print | while read -r page_path; do
    
    # 1. 计算输出路径
    rel_path=${page_path#$PAGES_DIR/}
    target_path="$SITE_DIR/$rel_path"
    mkdir -p "$(dirname "$target_path")"

    # 2. 读取页面内容
    content=$(cat "$page_path")

    # 3. 缺失组件检测
    # 提取页面中所有 {{name}} 标签
    tags=$(echo "$content" | grep -o '{{[a-zA-Z0-9._-]\+}}' | sort -u)
    for tag in $tags; do
        comp_name="${tag//\{/}"
        comp_name="${comp_name//\}/}"
        # 检查 components/name.html 是否存在
        if [ ! -f "$COMP_DIR/$comp_name.html" ]; then
            echo -e "  ${YELLOW}[警告]${NC} 页面 ${rel_path} 引用了不存在的组件: ${RED}${tag}${NC}"
        fi
    done

    # 4. 执行组件替换
    if [ -d "$COMP_DIR" ]; then
        for comp_path in "$COMP_DIR"/*.html; do
            [ -e "$comp_path" ] || continue
            comp_file=$(basename "$comp_path" .html)
            comp_content=$(cat "$comp_path")
            # Bash 原生字符串替换
            content="${content//\{\{$comp_file\}\}/$comp_content}"
        done
    fi

    # 5. 输出文件
    echo "$content" > "$target_path"
    echo "  已生成: $target_path"
done

echo -e "${GREEN}构建完成！${NC}"
