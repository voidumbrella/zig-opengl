const gl = @import("gl");
const glfw = @import("glfw");
const zmath = @import("zmath.zig");
const std = @import("std");

const pi = std.math.pi;
const cos = std.math.cos;
const sin = std.math.sin;

const Camera = @import("camera.zig").Camera;
const Model = @import("model.zig").Model;
const Shader = @import("shader.zig").Shader;

const SCR_WIDTH = 1200;
const SCR_HEIGHT = 900;

fn resizeCallback(window: glfw.Window, width: i32, height: i32) void {
    const camera = window.getUserPointer(Camera).?;
    gl.viewport(0, 0, @intCast(usize, width), @intCast(usize, height));
    camera.aspect_ratio = @intToFloat(f32, width) / @intToFloat(f32, height);
}

var xpos_last: f64 = undefined;
var ypos_last: f64 = undefined;
fn mouseCallback(window: glfw.Window, xpos: f64, ypos: f64) void {
    const camera = window.getUserPointer(Camera).?;
    const sensitivity = pi / 400.0;
    camera.yaw += sensitivity * @floatCast(f32, xpos - xpos_last);
    camera.pitch += sensitivity * @floatCast(f32, ypos_last - ypos);
    xpos_last = xpos;
    ypos_last = ypos;
    camera.pitch = std.math.clamp(camera.pitch, -pi / 2.05, pi / 2.05);
}

fn scrollCallback(window: glfw.Window, xoff: f64, yoff: f64) void {
    const camera = window.getUserPointer(Camera).?;
    _ = xoff;
    camera.fov -= @floatCast(f32, yoff * 0.1);
    camera.fov = std.math.clamp(camera.fov, pi / 40.0, pi / 2.5);
}

fn handleInputs(window: glfw.Window, dt: f32, camera: *Camera) void {
    const speed = 10;

    if (window.getKey(.escape) == .press) window.setShouldClose(true);
    if (window.getKey(.w) == .press) {
        camera.pos = zmath.mulAdd(camera.front(), zmath.f32x4s(dt * speed), camera.pos);
    }
    if (window.getKey(.s) == .press) {
        camera.pos = zmath.mulAdd(camera.front(), zmath.f32x4s(-dt * speed), camera.pos);
    }
    if (window.getKey(.a) == .press) {
        camera.pos = zmath.mulAdd(zmath.normalize3(zmath.cross3(camera.front(), camera.up)), zmath.f32x4s(-dt * speed), camera.pos);
    }
    if (window.getKey(.d) == .press) {
        camera.pos = zmath.mulAdd(zmath.normalize3(zmath.cross3(camera.front(), camera.up)), zmath.f32x4s(dt * speed), camera.pos);
    }
}

pub fn main() !void {
    const allocator = std.testing.allocator;

    // Window and input configuration
    try glfw.init(.{});
    defer glfw.terminate();
    const window = try glfw.Window.create(SCR_WIDTH, SCR_HEIGHT, "epic", null, null, .{});
    defer window.destroy();
    try glfw.makeContextCurrent(window);
    try window.setInputMode(.cursor, .disabled);
    window.setSizeCallback(resizeCallback);
    window.setCursorPosCallback(mouseCallback);
    window.setScrollCallback(scrollCallback);

    // Global OpenGL states
    gl.enable(.depth_test); // enable z-buffer

    // Compile shader
    const shader = try Shader.init("shaders/basic.vert", "shaders/basic.frag");

    // Camera setup
    var camera = Camera.init(
        zmath.f32x4(0.0, 0.0, 3.0, 0.0),
        -pi / 2.0,
        0.0,
        zmath.f32x4(0.0, 1.0, 0.0, 0.0),
        pi / 4.0,
        @intToFloat(f32, SCR_WIDTH) / @intToFloat(f32, SCR_HEIGHT),
    );
    window.setUserPointer(&camera);

    // Load model
    const obj = try Model.fromFile(allocator, "<insert model here>");

    // Main render loop
    // ------------------------------------------
    var t_prev: f32 = 0.0;
    // Set initial cursor position
    const cursor_pos = try window.getCursorPos();
    xpos_last = @floatCast(f32, cursor_pos.xpos);
    ypos_last = @floatCast(f32, cursor_pos.ypos);
    while (!window.shouldClose()) {
        // Get timestamps
        const t = @floatCast(f32, glfw.getTime());
        const dt = t - t_prev;
        t_prev = t;

        handleInputs(window, dt, &camera);

        // Clear frame buffer and z buffer
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        // Enable shader before doing anything
        shader.use();

        var light_pos = zmath.f32x4(5.0, 30.0, 0.0, 0.0);
        shader.uniformVec3("viewPos", camera.pos);
        shader.uniformVec3("light.position", light_pos);
        shader.uniformVec3("light.ambient", zmath.f32x4(0.3, 0.3, 0.3, 0.0));
        shader.uniformVec3("light.diffuse", zmath.f32x4(0.5, 0.5, 0.5, 0.0));
        shader.uniformVec3("light.specular", zmath.f32x4(1.0, 1.0, 1.0, 0.0));

        var modelMat = zmath.identity();
        modelMat = zmath.mul(modelMat, zmath.rotationY(t / 8.0));

        shader.uniformMat4("view", camera.viewMat());
        shader.uniformMat4("projection", camera.projectionMat());
        shader.uniformMat4("model", modelMat);
        obj.draw(shader);

        try window.swapBuffers();
        try glfw.pollEvents();
    }
}

fn degToRad(deg: f32) f32 {
    return deg * pi / 180.0;
}
