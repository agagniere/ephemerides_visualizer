const std = @import("std");
const raylib = @import("raylib");
const assets = @import("assets.zig");
const units = @import("units");

const Camera = raylib.Camera3D;
const Vector3 = raylib.Vector3;
const Texture = raylib.Texture2D;
const Shader = raylib.Shader;

const km = units.evalQuantity(f32, "km", .{});
const Mm = units.evalQuantity(f32, "Mm", .{});

const X: Vector3 = .{ .x = 1, .y = 0, .z = 0 };
const Y: Vector3 = .{ .x = 0, .y = 1, .z = 0 };
const Z: Vector3 = .{ .x = 0, .y = 0, .z = 1 };

const Planet = struct {
    radius: Mm,
    model: raylib.Model,

    fn init(radius: km) !Planet {
        const r = radius.to(Mm);
        const mesh = raylib.genMeshSphere(r.val(), 64, 64);

        return .{ .radius = r, .model = try .fromMesh(mesh) };
    }

    fn setShader(self: *Planet, shader: Shader) void {
        self.model.materials[0].shader = shader;
    }

    fn deinit(self: *Planet) void {
        self.model.unload();
    }
};

pub fn main() anyerror!void {
    const screenWidth = 1200;
    const screenHeight = 600;

    raylib.initWindow(screenWidth, screenHeight, "Visualize GNSS satellite orbits");
    defer raylib.closeWindow();
    raylib.setTargetFPS(60);

    var earth: Planet = try .init(.init(6_371));
    const earthPos: Vector3 = .{ .x = 0, .y = 0, .z = 0 };

    const earthDay = try raylib.loadImageFromMemory(".jpg", assets.texture.earth.day);
    defer earthDay.unload();
    const earthNight = try raylib.loadImageFromMemory(".jpg", assets.texture.earth.night);
    defer earthNight.unload();

    const earthShader = try raylib.loadShaderFromMemory(assets.shader.earth.vertex, assets.shader.earth.fragment);
    defer raylib.unloadShader(earthShader);

    var camera: Camera = .{
        .position = .{ .x = 10, .y = 10, .z = 10 },
        .target = earthPos,
        .up = Y,
        .fovy = 70.0,
        .projection = .perspective,
    };

    while (!raylib.windowShouldClose()) {
        camera.update(.orbital);

        {
            raylib.beginDrawing();
            defer raylib.endDrawing();

            raylib.clearBackground(.black);
            {
                camera.begin();
                defer camera.end();

                earth.model.draw(earthPos, 1, .white);
                //earthCloudModel.draw(earthPos, 1, .white);
                raylib.drawCircle3D(earthPos, earth.radius.val() * 2, X.add(Y), 90.0, .light_gray);
                raylib.drawCircle3D(earthPos, earth.radius.val() * 3, X, 90.0, .gray);
            }
        }
    }
}
