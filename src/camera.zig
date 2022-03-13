const zmath = @import("zmath.zig");
const std = @import("std");

const cos = std.math.cos;
const sin = std.math.sin;

pub const Camera = struct {
    pos: zmath.Vec,
    up: zmath.Vec,
    yaw: f32,
    pitch: f32,
    fov: f32,
    aspect_ratio: f32,

    pub fn init(
        pos: zmath.Vec,
        yaw: f32,
        pitch: f32,
        up: zmath.Vec,
        fov: f32,
        aspect_ratio: f32,
    ) Camera {
        return .{
            .pos = pos,
            .yaw = yaw,
            .pitch = pitch,
            .up = zmath.normalize3(up),
            .fov = fov,
            .aspect_ratio = aspect_ratio,
        };
    }

    pub fn front(self: Camera) zmath.Vec {
        return zmath.f32x4(
            cos(self.yaw) * cos(self.pitch),
            sin(self.pitch),
            sin(self.yaw) * cos(self.pitch),
            0.0,
        );
    }

    pub fn viewMat(self: *Camera) zmath.Mat {
        return zmath.lookToRh(self.pos, self.front(), self.up);
    }

    pub fn projectionMat(self: *Camera) zmath.Mat {
        return zmath.perspectiveFovRh(self.fov, self.aspect_ratio, 0.1, 1000);
    }
};
