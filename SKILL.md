---
name: julia-repl-server
description: This skill should be used when users need to execute Julia code with zero-compilation time through a persistent REPL server. It provides a clean communication bridge between Claude and a running Julia process, enabling instant code execution without startup delays.
---

# Julia REPL Server Skill

## Purpose

Enable zero-compilation-time Julia development through a persistent REPL server that maintains session state and supports hot reloading.

## When to Use

Use this skill when users request:
- Julia code execution with immediate results
- Scientific computing and data analysis
- Interactive development and debugging
- Code testing without restarting Julia
- Performance benchmarking
- Signal processing or mathematical computations

## How to Use

### Prerequisites

Ensure Julia 1.11+ is installed and these packages are available:
- Revise, Plots, DataFrames, CSV, FFTW, ITensors, BenchmarkTools

Install with:
```julia
import Pkg; Pkg.add(["Revise", "Plots", "DataFrames", "CSV", "FFTW", "ITensors", "BenchmarkTools"])
```

### Start the Server

Start the Julia REPL server using the skill's bundled script:

```bash
# Start the server (runs in background)
julia --project= path/to/skill/scripts/julia_server.jl
```

The server will output:
```
🤖 Julia 服务器已启动
📦 所有包已加载
🔄 Revise 热重载已激活
🎯 服务器准备就绪，等待命令...
```

### Execute Julia Code

Use the JuliaREPLHelper to send commands:

```julia
# Load the helper module
include("path/to/skill/scripts/JuliaREPLHelper.jl")
using .JuliaREPLHelper

# Execute basic commands
response = send_command("2 + 2")
# Returns: "✅ 执行成功: 4"

# Include Julia files
response = send_command("include(\"my_script.jl\")")

# Execute Julia functions and packages
response = send_command("using DataFrames, Plots")
response = send_command("df = DataFrame(A=1:5, B=rand(5))")
response = send_command("plot(1:10, rand(10))")
```

### Available Preloaded Packages

The server comes with these packages pre-loaded:
- **DataFrames**: Data manipulation and analysis
- **CSV**: CSV file handling
- **Plots**: Data visualization
- **ITensors**: Tensor computations
- **FFTW**: Fast Fourier Transform
- **BenchmarkTools**: Performance benchmarking
- **Revise**: Hot reloading support

### Communication Method

The skill uses file-based communication:
- Commands written to `julia_command.txt`
- Responses read from `julia_response.txt`
- Automatic file cleanup after each operation

### Error Handling

Errors are captured and returned as formatted messages:
```
❌ 错误: UndefVarError(:undefined_function, 0x0000000000009823, Main)
```

The server continues running after errors, allowing immediate retries.

### Hot Reload Workflow

Modify Julia code files and reload without restarting:
```julia
send_command("include(\"my_script.jl\")")
# Modify my_script.jl
send_command("include(\"my_script.jl\")")  # Changes apply immediately
```

## Core Components

#### `scripts/julia_server.jl` - The Persistent REPL Server

This is the main server process that runs in the background and maintains a continuous Julia session.

**Key Features:**
- **Preloaded Environment**: Automatically loads essential scientific computing packages (DataFrames, Plots, FFTW, ITensors, etc.) on startup
- **Revise Integration**: Hot reloading support for code changes without server restart
- **File-based Communication**: Listens for commands in `julia_command.txt` and writes responses to `julia_response.txt`
- **Robust Error Handling**: Captures and formats all errors without crashing the server
- **Universal Command Execution**: Processes any valid Julia code through `eval(Meta.parse())`

**Startup Process:**
1. Loads all preconfigured packages
2. Initializes Revise for hot reloading
3. Sets up communication files
4. Enters infinite polling loop (0.5s intervals)
5. Processes commands as they appear

**Command Processing Logic:**
- File inclusion commands (`include("file.jl")`) get special handling for clean responses
- All other commands are evaluated as raw Julia code
- Results and errors are formatted consistently with emoji indicators

#### `scripts/JuliaREPLHelper.jl` - The Client Communication Module

This module provides the client-side interface for communicating with the running server.

**Core Functions:**
- **`send_command(command, timeout=10)`**: Sends commands and waits for responses
  - Writes command to `julia_command.txt`
  - Polls for response file with configurable timeout
  - Automatically cleans up temporary files
  - Returns formatted response string

- **`check_response()`**: Manually checks for pending responses without sending new commands
- **`send_julia_command`**: Alias for `send_command` for API compatibility

**Communication Protocol:**
1. Client writes command to `julia_command.txt`
2. Server detects file, processes command, writes response to `julia_response.txt`
3. Client waits for response file, reads content, cleans up
4. Both command and response files are automatically deleted after processing

**Error Handling:**
- Network-style timeouts prevent hanging indefinitely
- Clean file management prevents resource leaks
- All responses include success/error status indicators

## Best Practices

1. Keep the server running for the entire development session
2. Use `send_command()` for all Julia code execution
3. Check response format to detect success vs errors - success starts with "✅", errors with "❌"
4. Load required packages first: `send_command("using DataFrames, Plots")`
5. Leverage hot reload for iterative development - modify code and re-include immediately