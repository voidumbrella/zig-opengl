const gl = @import("gl");
const glfw = @import("glfw");
const zmath = @import("zmath.zig");

const std = @import("std");
var allocator = std.testing.allocator;

pub const Shader = struct {
    program: gl.Program,

    pub fn init(vert_path: []const u8, frag_path: []const u8) !Shader {
        var vert_src_file = try std.fs.cwd().openFile(vert_path, .{});
        var frag_src_file = try std.fs.cwd().openFile(frag_path, .{});
        var vert_src = try vert_src_file.readToEndAlloc(allocator, std.math.maxInt(usize));
        var frag_src = try frag_src_file.readToEndAlloc(allocator, std.math.maxInt(usize));

        var vertex_shader = gl.Shader.create(.vertex);
        _ = vertex_shader;
        vertex_shader.source(1, &vert_src);
        vertex_shader.compile();
        if (vertex_shader.get(.compile_status) == 0) {
            const msg = try vertex_shader.getCompileLog(allocator);
            std.log.err("Could not compile vertex shader: {s}", .{msg});
            return error.CompileFail;
        }

        var fragment_shader = gl.Shader.create(.fragment);
        _ = fragment_shader;
        fragment_shader.source(1, &frag_src);
        fragment_shader.compile();
        if (fragment_shader.get(.compile_status) == 0) {
            const msg = try fragment_shader.getCompileLog(allocator);
            std.log.err("Could not compile fragment shader: {s}", .{msg});
            return error.CompileFail;
        }

        // Create a shader program and link the compiled shaders.
        var program = gl.Program.create();
        program.attach(vertex_shader);
        program.attach(fragment_shader);
        program.link();
        if (program.get(.link_status) == 0) {
            const msg = try program.getCompileLog(allocator);
            std.log.err("Could not link shader program: {s}", .{msg});
            return error.LinkFail;
        }
        // The shaders are linked and no longer needed around.
        vertex_shader.delete();
        fragment_shader.delete();
        return Shader{ .program = program };
    }

    pub fn use(self: Shader) void {
        self.program.use();
    }

    pub fn uniformBool(self: Shader, name: [:0]const u8, value: bool) void {
        self.program.uniform1i(self.program.uniformLocation(name), value);
    }

    pub fn uniformi32(self: Shader, name: [:0]const u8, value: i32) void {
        self.program.uniform1i(self.program.uniformLocation(name), value);
    }

    pub fn uniformf32(self: Shader, name: [:0]const u8, value: f32) void {
        self.program.uniform1f(self.program.uniformLocation(name), value);
    }

    pub fn uniformVec3(self: Shader, name: [:0]const u8, vec: zmath.Vec) void {
        self.program.uniform3f(self.program.uniformLocation(name), vec[0], vec[1], vec[2]);
    }

    pub fn uniformMat4(self: Shader, name: [:0]const u8, mat: zmath.Mat) void {
        self.program.uniformMatrix4(self.program.uniformLocation(name), false, @ptrCast([*]const [4][4]f32, &zmath.matToArray(mat))[0..1]);
    }
};
