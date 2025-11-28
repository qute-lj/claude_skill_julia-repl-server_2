"""
Julia REPL助手模块 - 与后台Julia服务器通信

使用方法:
using .JuliaREPLHelper

# 发送命令并获取响应
response = send_command("1 + 1")
response = send_command("include(\"workspace.jl\")")
response = send_command("quick_fft_test()")
"""

module JuliaREPLHelper

export send_command, send_julia_command, check_response

const COMMAND_FILE = "julia_command.txt"
const RESPONSE_FILE = "julia_response.txt"

function send_command(command::String; timeout::Int=10)
    """
    向后台Julia服务器发送命令并等待响应

    Args:
        command: 要执行的Julia命令
        timeout: 超时时间（秒）

    Returns:
        服务器的响应字符串
    """
    # 写入命令文件
    open(COMMAND_FILE, "w") do f
        write(f, command)
    end

    println("📤 命令已发送: $command")

    # 等待响应
    start_time = time()
    while !isfile(RESPONSE_FILE)
        sleep(0.1)
        if time() - start_time > timeout
            return "⏰ 超时：未收到响应"
        end
    end

    # 读取响应
    response = read(RESPONSE_FILE, String)
    rm(RESPONSE_FILE)  # 删除响应文件

    println("📥 收到响应: $response")
    return strip(response)
end

# 便捷别名
const send_julia_command = send_command

function check_response()
    """检查是否有待处理的响应"""
    if isfile(RESPONSE_FILE)
        response = read(RESPONSE_FILE, String)
        rm(RESPONSE_FILE)
        return strip(response)
    else
        return "⏳ 没有待处理的响应"
    end
end


end