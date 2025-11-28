# Julia 服务器 - 通过文件与Claude Code通信
# 启动方式: julia --project=. julia_server.jl

using Revise
using Plots
using DataFrames
using CSV
using BenchmarkTools
using FFTW
using ITensors

println("🤖 Julia 服务器已启动")
println("📦 所有包已加载")
println("🔄 Revise 热重载已激活")
println("=" ^ 50)

# 通信文件路径
COMMAND_FILE = "julia_command.txt"
RESPONSE_FILE = "julia_response.txt"

# 删除可能存在的旧文件
if isfile(COMMAND_FILE)
    rm(COMMAND_FILE)
end
if isfile(RESPONSE_FILE)
    rm(RESPONSE_FILE)
end

println("💡 通信文件: $COMMAND_FILE -> $RESPONSE_FILE")

# 命令处理函数
function process_command(command)
    try
        if startswith(command, "include(")
            # 处理文件包含命令
            eval(Meta.parse(command))
            return "✅ 文件加载成功"
        else
            # 尝试执行任意Julia代码
            result = eval(Meta.parse(command))
            return "✅ 执行成功: $(string(result))"
        end
    catch e
        return "❌ 错误: $e"
    end
end


# 主循环 - 监听命令文件
println("🎯 服务器准备就绪，等待命令...")
println("💡 向 $COMMAND_FILE 写入命令即可执行")

while true
    sleep(0.5)  # 每0.5秒检查一次

    if isfile(COMMAND_FILE)
        # 读取命令
        command = strip(read(COMMAND_FILE, String))

        if !isempty(command)
            println("📨 收到命令: $command")

            # 处理命令
            response = process_command(command)
            println("📤 响应: $response")

            # 写入响应
            open(RESPONSE_FILE, "w") do f
                write(f, response)
            end

            # 删除命令文件
            rm(COMMAND_FILE)

            println("✅ 命令处理完成")
        end
    end
end