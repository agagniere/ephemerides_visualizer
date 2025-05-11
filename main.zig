const std = @import("std");
const raylib = @import("raylib");
const assets = @import("assets.zig");
const units = @import("units");

const Camera = raylib.Camera3D;
const Vector3 = raylib.Vector3;
const Texture = raylib.Texture2D;
const Shader = raylib.Shader;
const gl = raylib.gl;

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
        image.rotateCCW();
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

pub fn main() anyerror!void {
    const screenWidth = 1200;
    const screenHeight = 600;

    raylib.setConfigFlags(.{ .msaa_4x_hint = true, .vsync_hint = true });
    raylib.initWindow(screenWidth, screenHeight, "Visualize GNSS satellite orbits");
    defer raylib.closeWindow();
    raylib.setTargetFPS(60);

    var icon = try raylib.loadImageFromMemory(".png", assets.icon);
    defer icon.unload();
    icon.setFormat(.uncompressed_r8g8b8a8);
    icon.useAsWindowIcon();

    var earth: Planet = try .init(.init(6_371));
    const earthPos: Vector3 = .{ .x = 0, .y = 0, .z = 0 };
    const earthShader = try raylib.loadShaderFromMemory(assets.shader.earth.vertex, assets.shader.earth.fragment);
    defer raylib.unloadShader(earthShader);
    earth.setShader(earthShader);
    try earth.addTexture(0, ".jpg", assets.texture.earth.day);
    try earth.addTexture(1, ".jpg", assets.texture.earth.night);
    try earth.addTexture(2, ".jpg", assets.texture.earth.clouds);
    const loc_sundir = raylib.getShaderLocation(earth.getShader(), "sun_dir");

    var camera: Camera = .{
        .position = .{ .x = 15, .y = 5, .z = 15 },
        .target = earthPos,
        .up = Y,
        .fovy = 65.0,
        .projection = .perspective,
    };
    var sunRotation: f32 = 0;
    var earthRotation: f32 = 0;
    var sunPos: Vector3 = .{ .x = 200, .y = 0, .z = 0 };

    while (!raylib.windowShouldClose()) {
        camera.update(.orbital);
        //camera.update(.free);
        sunRotation += 0.1;
        earthRotation += 1;
        const nsd = sunPos.normalize();
        const sun_dir: [3]f32 = .{ nsd.x, nsd.y, nsd.z };
        raylib.setShaderValue(earth.getShader(), loc_sundir, &sun_dir, .vec3);

        {
            raylib.beginDrawing();
            defer raylib.endDrawing();

            raylib.clearBackground(.black);
            {
                camera.begin();
                defer camera.end();

                {
                    gl.rlPushMatrix();
                    defer gl.rlPopMatrix();

                    gl.rlRotatef(67, 1, 0, 0);
                    raylib.drawCircle3D(earthPos, earth.radius.val() * 2, X, 0, .gray);

                    {
                        gl.rlPushMatrix();
                        defer gl.rlPopMatrix();

                        gl.rlRotatef(-earthRotation, 0, 0, 1);
                        earth.model.draw(earthPos, 1, .white);
                    }
                }

                raylib.drawCircle3D(earthPos, earth.radius.val() * 2, X, 90, .dark_gray);

                {
                    gl.rlPushMatrix();
                    defer gl.rlPopMatrix();

                    gl.rlRotatef(-sunRotation, 0, 1, 0);
                    gl.rlTranslatef(200, 0, 0);
                    raylib.drawSphere(Vector3.zero(), 5, .yellow);
                    sunPos = Vector3.zero().transform(gl.rlGetMatrixTransform());
                }
                //raylib.drawGrid(10, 5);
            }
        }
    }
}
