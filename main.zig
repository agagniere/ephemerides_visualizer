const std = @import("std");
const builtin = @import("builtin");

const raylib = @import("raylib");
const assets = @import("src/assets.zig");
const units = @import("units");
const log_config = @import("src/log.zig");

const Camera = raylib.Camera3D;
const Vector3 = raylib.Vector3;
const Texture = raylib.Texture2D;
const Shader = raylib.Shader;
const gl = raylib.gl;
const log = log_config.axe_log;

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

    fn addTexture(self: *Planet, id: u8, extension: [:0]const u8, asset: []const u8) !void {
        var image = try raylib.loadImageFromMemory(extension, asset);
        image.flipVertical();
        image.rotateCW();
        const texture = try image.toTexture();
        //const location = raylib.getShaderLocation(self.getShader(), name);
        //raylib.setShaderValueTexture(self.getShader(), location, texture);
        self.model.materials[0].maps[id].texture = texture;
    }

    fn getShader(self: Planet) Shader {
        return self.model.materials[0].shader;
    }

    fn deinit(self: *Planet) void {
        self.model.unload();
    }
};

fn drawVector(vector: Vector3, color: raylib.Color) void {
    raylib.drawCylinderEx(Vector3.zero(), vector.scale(0.8), 0.1, 0.1, 10, color);
    raylib.drawCylinderEx(vector.scale(0.8), vector, 0.5, 0.01, 20, color);
}

pub const std_options: std.Options = .{
    .logFn = log.log,
    .log_level = .debug,
    .log_scope_levels = &.{
        .{ .scope = .raylib, .level = .debug }, // Raylib logs
        .{ .scope = .shader, .level = .debug }, // Shader compilation errors
    },
};

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const gpa = switch (builtin.mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
    };

    try log_config.init(gpa, .all);
    defer log_config.deinit(gpa);

    raylib.setConfigFlags(.{
        .msaa_4x_hint = true,
        .vsync_hint = true,
        .fullscreen_mode = true,
        .window_resizable = true,
    });
    raylib.initWindow(1920, 1080, "Visualize GNSS satellite orbits");
    defer raylib.closeWindow();
    raylib.setTargetFPS(60);

    var icon = try raylib.loadImageFromMemory(".png", assets.icon);
    defer icon.unload();
    icon.setFormat(.uncompressed_r8g8b8a8);
    icon.useAsWindowIcon();

    var earth: Planet = try .init(.init(6_371));
    const earthPos: Vector3 = .zero();
    const earthShader = try raylib.loadShaderFromMemory(assets.shader.earth.vertex, assets.shader.earth.fragment);
    defer raylib.unloadShader(earthShader);
    earth.setShader(earthShader);
    try earth.addTexture(0, ".jpg", assets.texture.earth.day);
    try earth.addTexture(1, ".jpg", assets.texture.earth.night);
    try earth.addTexture(2, ".jpg", assets.texture.earth.clouds);
    const loc_sundir = raylib.getShaderLocation(earth.getShader(), "sun_dir");

    var camera: Camera = .{
        .position = .{ .x = 10, .y = -20, .z = 5 },
        .target = earthPos,
        .up = Z,
        .fovy = 65.0,
        .projection = .perspective,
    };
    var sunRotation: f32 = 0;
    var earthRotation: f32 = 0;
    var sunPos: Vector3 = .{ .x = 0, .y = 200, .z = 0 };

    raylib.disableCursor();
    while (!raylib.windowShouldClose()) {
        camera.update(.third_person);
        sunRotation += 0.01;
        earthRotation += 0.5;
        const nsd = sunPos.normalize();
        const sun_dir: [3]f32 = .{ nsd.x, nsd.y, nsd.z };
        raylib.setShaderValue(earth.getShader(), loc_sundir, &sun_dir, .vec3);

        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(.black);
        {
            camera.begin();
            defer camera.end();

            drawVector(X.scale(20), .white);
            drawVector(Y.scale(20), .red);
            drawVector(Z.scale(20), .green);

            {
                gl.rlPushMatrix();
                defer gl.rlPopMatrix();

                gl.rlRotatef(23.5, 1, 0, 0);

                //drawVector(X.scale(10), .white);
                drawVector(Y.scale(10), .red);
                drawVector(Z.scale(10), .green);

                raylib.drawCircle3D(earthPos, earth.radius.val() * 1.5, X, 0, .gray);
                //camera.up = Z.transform(gl.rlGetMatrixTransform());

                {
                    gl.rlPushMatrix();
                    defer gl.rlPopMatrix();

                    gl.rlRotatef(-earthRotation, 0, 0, 1);
                    drawVector(X.scale(10), .white);
                    drawVector(Y.scale(10), .red);
                    //drawVector(Z.scale(10), .green);
                    earth.model.draw(earthPos, 1, .white);
                }
            }

            raylib.drawCircle3D(earthPos, earth.radius.val() * 2, X, 0, .dark_gray);
            raylib.drawCircle3D(earthPos, earth.radius.val() * 3, X, 0, .dark_gray);
            raylib.drawCircle3D(earthPos, earth.radius.val() * 4, X, 0, .dark_gray);

            {
                gl.rlPushMatrix();
                defer gl.rlPopMatrix();

                gl.rlRotatef(-sunRotation, 0, 0, 1);
                gl.rlTranslatef(0, 200, 0);
                raylib.drawSphere(Vector3.zero(), 5, .yellow);
                sunPos = Vector3.zero().transform(gl.rlGetMatrixTransform());
            }
        }
    }
}
