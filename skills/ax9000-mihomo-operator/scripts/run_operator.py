import re
import sys

def process(input_path, output_path):
    with open(input_path, 'r') as f:
        content = f.read()

    # 1. 脫敏：將 server, uuid, password, sni, Host 替換為 placeholder
    content = re.sub(r'(server|uuid|password|sni|Host|path):.*', r'\1: YOUR-PLACEHOLDER', content)

    # 2. 注入電視盒子規則：在 rules: 後插入
    rule = "\n  - SRC-IP-CIDR,192.168.31.39/32,auto"
    if "rules:" in content and "SRC-IP-CIDR,192.168.31.39/32,auto" not in content:
        content = content.replace("rules:", "rules:" + rule)

    with open(output_path, 'w') as f:
        f.write(content)
    print(f"安全脫敏並植入規則完成: {output_path}")

process('/Users/whypuss/projects/ax9000-mihomo-docker/configs/mihomo_config_origin.yaml', '/Users/whypuss/projects/ax9000-mihomo-docker/configs/mihomo_config_template.yaml')
