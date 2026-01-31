#!/bin/bash
# 1. 필수 패키지 설치
yum update -y
yum install -y nginx python3 python3-pip

# 2. Flask 및 Gunicorn 설치
pip3 install flask gunicorn

# 3. Flask API 앱 작성 (상세 메타데이터 포함)
cat << 'EOF' > /home/ec2-user/app.py
from flask import Flask, render_template_string
import random
import socket
import platform
import subprocess
import requests
import time
import os
from multiprocessing import Pool

app = Flask(__name__)

# HTML 템플릿 (vCPU 개수 및 멀티코어 결과 추가)
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>EC2 Multi-Core Benchmark</title>
    <link href="https://cdn.jsdelivr.net" rel="stylesheet">
    <style>
        body { background-color: #f8f9fa; padding-top: 50px; }
        .container { max-width: 900px; background: white; padding: 30px; border-radius: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .table th { width: 35%; background-color: #e9ecef; }
        .header-title { color: #0d6efd; margin-bottom: 25px; font-weight: bold; }
        .highlight { font-weight: bold; color: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <h2 class="header-title text-center">🚀 EC2 Multi-Core Performance: {{ data.architecture }}</h2>
        <table class="table table-bordered">
            <tbody>
                {% for key, value in data.items() %}
                <tr>
                    <th>{{ key.replace('_', ' ').title() }}</th>
                    <td class="{{ 'highlight' if key == 'execution_time' else '' }}">{{ value }}</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        <div class="text-center mt-4">
            <button class="btn btn-danger" onclick="location.reload()">Run Multi-Core Test Again</button>
        </div>
    </div>
</body>
</html>
"""

def get_metadata(path):
    try:
        token_url = "http://169.254.169.254"
        token = requests.put(token_url, headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"}, timeout=1).text
        url = f"http://169.254.169.254{path}"
        res = requests.get(url, headers={"X-aws-ec2-metadata-token": token}, timeout=1)
        return res.text if res.status_code == 200 else "N/A"
    except:
        return "N/A"

# 각 프로세스가 실행할 연산 함수
def monte_carlo_task(n):
    hits = 0
    for _ in range(n):
        x, y = random.random(), random.random()
        if x*x + y*y <= 1.0:
            hits += 1
    return hits

@app.route('/')
def simulate():
    # 전체 시뮬레이션 횟수 (코어당 100만 번씩 수행)
    cpu_count = os.cpu_count()
    iterations_per_cpu = 1000000
    total_iterations = cpu_count * iterations_per_cpu

    start_time = time.perf_counter()
    
    # 멀티프로세싱 풀 생성 (모든 vCPU 활용)
    with Pool(processes=cpu_count) as pool:
        # 각 코어에 작업을 할당하고 결과를 합산
        total_hits = sum(pool.map(monte_carlo_task, [iterations_per_cpu] * cpu_count))
    
    end_time = time.perf_counter()
    duration = end_time - start_time

    result_data = {
        "instance_name": get_metadata("tags/instance/Name"),
        "instance_type": get_metadata("instance-type"),
        "architecture": platform.machine(),
        "cpu_model": subprocess.getoutput("lscpu | grep 'Model name' | cut -d: -f2").strip(),
        "total_vcpus": cpu_count,
        "total_iterations": f"{total_iterations:,}",
        "execution_time": f"{duration:.4f} seconds",
        "pi_estimate": 4.0 * total_hits / total_iterations,
        "private_ip": get_metadata("local-ipv4")
    }

    return render_template_string(HTML_TEMPLATE, data=result_data)

if __name__ == "__main__":
    # Flask 앱 실행
    app.run(host='0.0.0.0', port=8080)
