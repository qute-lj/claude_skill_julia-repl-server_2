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

export send_command, send_julia_command, check_response, get_server_info, truncate_string

function load_server_config()
    """从用户主目录加载服务器配置"""
    config_path = joinpath(homedir(), ".julia_repl_server_config.jl")

    if !isfile(config_path)
        error("❌ 未找到运行中的Julia REPL服务器。请先启动 julia_server.jl")
    end

    # 直接读取配置文件内容并解析
    local server_id, command_file, response_file, comm_dir, start_time

    try
        config_content = read(config_path, String)

        # 逐行解析配置
        for line in split(config_content, '\n')
            if startswith(line, "SERVER_ID = ")
                server_id = replace(line, "SERVER_ID = " => "")[2:end-1]  # 移除引号
            elseif startswith(line, "COMMAND_FILE = ")
                command_file = replace(line, "COMMAND_FILE = " => "")[2:end-1]
            elseif startswith(line, "RESPONSE_FILE = ")
                response_file = replace(line, "RESPONSE_FILE = " => "")[2:end-1]
            elseif startswith(line, "COMM_DIR = ")
                comm_dir = replace(line, "COMM_DIR = " => "")[2:end-1]
            elseif startswith(line, "START_TIME = ")
                start_time = replace(line, "START_TIME = " => "")[2:end-1]
            end
        end

        # 将正斜杠路径转换回系统路径（Windows需要反斜杠）
        if Sys.iswindows()
            command_file = replace(command_file, "/" => "\\")
            response_file = replace(response_file, "/" => "\\")
            comm_dir = replace(comm_dir, "/" => "\\")
        end

    catch e
        error("❌ 配置文件读取失败: $e")
    end

    return server_id, command_file, response_file, comm_dir, start_time
end

function get_comm_files()
    """获取通信文件路径"""
    try
        _, command_file, response_file, _, _ = load_server_config()
        return command_file, response_file
    catch e
        rethrow(e)
    end
end

function get_server_info()
    """获取服务器信息"""
    try
        server_id, _, _, comm_dir, start_time = load_server_config()
        println("🔗 服务器ID: $server_id")
        println("📡 通信目录: $comm_dir")
        println("⏰ 启动时间: $start_time")
        return server_id, comm_dir
    catch e
        rethrow(e)
    end
end

function send_command(command::String; timeout::Int=10)
    """
    向后台Julia服务器发送命令并等待响应

    Args:
        command: 要执行的Julia命令
        timeout: 超时时间（秒）

    Returns:
        服务器的响应字符串
    """
    command_file, response_file = get_comm_files()  # 动态获取路径

    # 预处理命令检查
    if isempty(strip(command))
        return "❌ 错误: 命令不能为空"
    end

    # 检查常见语法问题
    if command_has_syntax_issues(command)
        return "❌ 警告: 检测到可能的语法问题，请检查引号和括号匹配"
    end

    # 检查服务器是否运行
    if !isfile(command_file) && !isfile(response_file)
        # 尝试创建测试文件检查权限
        try
            open(command_file, "w") do f
                write(f, "test")
            end
            rm(command_file)
        catch e
            error("❌ 服务器通信失败，请检查服务器是否运行")
        end
    end

    # 写入命令文件 - 使用安全的写入方式
    try
        open(command_file, "w") do f
            write(f, command)
        end
    catch e
        return "❌ 错误: 无法写入命令文件 - $e"
    end

    display_command = length(command) > 50 ? command[1:47] * "..." : command
println("📤 命令已发送: $display_command")

    # 等待响应 - 优化轮询速度
    start_time = time()
    while !isfile(response_file)
        sleep(0.05)  # 从0.1秒优化到0.05秒
        if time() - start_time > timeout
            return "⏰ 超时：未收到响应 (服务器可能正在处理复杂命令)"
        end
    end

    # 读取响应
    try
        response = read(response_file, String)
        rm(response_file)  # 删除响应文件

        response = strip(response)

        # 简单截断显示
        display_response = length(response) > 100 ? response[1:97] * "..." : response
        println("📥 收到响应: $display_response")

        # 分析响应类型并提供额外信息
        if startswith(response, "❌ 错误:")
            println("⚠️  命令执行失败，请查看服务器日志获取详细信息")
        elseif startswith(response, "✅ 执行成功:")
            println("✅ 命令执行成功")
        end

        return response
    catch e
        return "❌ 错误: 无法读取响应文件 - $e"
    end
end

# 辅助函数：检查常见语法问题
function command_has_syntax_issues(command::String)
    # 检查未匹配的引号
    single_quote_count = count(c -> c == '\'', command)
    double_quote_count = count(c -> c == '"', command)

    if single_quote_count % 2 != 0 || double_quote_count % 2 != 0
        return true
    end

    # 检查未匹配的括号
    open_parens = count(c -> c == '(', command)
    close_parens = count(c -> c == ')', command)
    if open_parens != close_parens
        return true
    end

    open_brackets = count(c -> c == '[', command)
    close_brackets = count(c -> c == ']', command)
    if open_brackets != close_brackets
        return true
    end

    return false
end

# 辅助函数：截断长字符串
function truncate_string(s::String, max_len::Int)
    if length(s) <= max_len
        return s
    else
        return s[1:max_len-3] * "..."
    end
end

# 便捷别名
const send_julia_command = send_command

function check_response()
    """检查是否有待处理的响应"""
    _, response_file = get_comm_files()  # 使用动态路径

    if isfile(response_file)
        response = read(response_file, String)
        rm(response_file)
        return strip(response)
    else
        return "⏳ 没有待处理的响应"
    end
end


end