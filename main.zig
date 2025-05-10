const std = @import("std");
const raylib = @import("raylib");
const assets = @import("assets.zig");
const units = @import("units");

const Camera = raylib.Camera3D;
const Vector3 = raylib.Vector3;
const Texture = raylib.Texture2D;

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

    fn setTexture(self: *Planet, texture: Texture) void {
        self.model.materials[0].maps[0].texture = texture;
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
    var earthImage = try raylib.loadImageFromMemory(".jpg", assets.earth_day);
    defer earthImage.unload();
    earthImage.flipVertical();
    earthImage.rotateCCW();
    const earthTexture = try raylib.loadTextureFromImage(earthImage);
    defer earthTexture.unload();
    earth.setTexture(earthTexture);
    earth.model.transform = raylib.Matrix.rotateX(67 * std.math.rad_per_deg);

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
