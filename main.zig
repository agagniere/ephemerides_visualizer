const std = @import("std");
const builtin = @import("builtin");

const raylib = @import("raylib");
const assets = @import("src/assets.zig");
const units = @import("units");
const log_config = @import("src/log.zig");
const astrotex = @import("astronomy_textures");

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

    fn addTexture(self: *Planet, name: [:0]const u8, extension: [:0]const u8, asset: []const u8, locationIndex: raylib.ShaderLocationIndex, mapIndex: raylib.MaterialMapIndex) !void {
        var image = try raylib.loadImageFromMemory(extension, asset);
        image.flipVertical();
        image.rotateCW();
        const texture = try image.toTexture();
        raylib.setTextureFilter(texture, .anisotropic_16x);
        const i: usize = @intCast(@intFromEnum(locationIndex));
        const j: usize = @intCast(@intFromEnum(mapIndex));
        self.getShader().locs[i] = raylib.getShaderLocation(self.getShader(), name);
        if (self.getShader().locs[i] == -1)
            return error.NoSuchUniform;
        self.model.materials[0].maps[j].texture = texture;
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
        .{ .scope = .raylib, .level = .warn }, // Raylib logs
        .{ .scope = .shader, .level = .debug }, // Shader compilation errors
    },
};

const camera_rotation_sensitivity = 0.003;

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

    const earthShader = try raylib.loadShaderFromMemory(assets.shader.earth.vertex, assets.shader.earth.fragment);
    defer raylib.unloadShader(earthShader);

    var earth: Planet = try .init(.init(6_371));
    const earthPos: Vector3 = .zero();
    earth.setShader(earthShader);
    try earth.addTexture("texture_day", ".jpg", assets.texture.earth.day, .map_albedo, .albedo);
    try earth.addTexture("texture_night", ".jpg", assets.texture.earth.night, .map_emission, .emission);
    try earth.addTexture("texture_clouds", ".jpg", assets.texture.earth.clouds, .map_occlusion, .occlusion);
    try earth.addTexture("texture_specular", ".jpg", assets.texture.earth.specular, .map_metalness, .metalness);
    const loc_sundir = raylib.getShaderLocation(earth.getShader(), "sun_dir");
    if (loc_sundir == -1)
        return error.NoSuchUniform;
    const loc_campos = raylib.getShaderLocation(earth.getShader(), "cam_pos");
    if (loc_campos == -1)
        return error.NoSuchUniform;
    earth.model.transform = raylib.Matrix.rotate(Z, std.math.pi);

    var icon = try raylib.loadImageFromMemory(".png", assets.icon);
    defer icon.unload();
    icon.setFormat(.uncompressed_r8g8b8a8);
    icon.useAsWindowIcon();

    const skyboxMesh = raylib.genMeshSphere(550, 16, 16);
    var skybox: raylib.Model = try .fromMesh(skyboxMesh);
    defer skybox.unload();

    var skyboxImage = try raylib.loadImageFromMemory(".jpg", astrotex.skybox.stars);
    defer skyboxImage.unload();
    skyboxImage.flipVertical();
    skyboxImage.flipHorizontal();
    skyboxImage.rotateCW();
    const skyboxTexture = try skyboxImage.toTexture();
    defer skyboxTexture.unload();
    skybox.materials[0].maps[0].texture = skyboxTexture;
    skybox.transform = raylib.Matrix.rotate(Y, -std.math.pi / 3.0);

    var cameraOffset: Vector3 = .{ .x = 20, .y = 0, .z = 5 };
    var camera: Camera = .{
        .position = cameraOffset,
        .target = earthPos,
        .up = Z,
        .fovy = 65.0,
        .projection = .perspective,
    };
    var sunRotation: f32 = 0;
    var earthRotation: f32 = 0;
    var sunPos: Vector3 = .{ .x = 0, .y = 500, .z = 0 };

    raylib.disableCursor();
    while (!raylib.windowShouldClose()) {
        const mouseDelta = raylib.getMouseDelta();
        const mouseZoom = raylib.getMouseWheelMove();
        const distToTarget = earthPos.distance(cameraOffset);
        if (mouseZoom < 0 or distToTarget > earth.radius.val() * 2)
            cameraOffset = cameraOffset.add(earthPos.subtract(cameraOffset).normalize().scale(mouseZoom));
        cameraOffset = cameraOffset.rotateByAxisAngle(Z, -mouseDelta.x * camera_rotation_sensitivity);

        sunRotation += 0.01;
        earthRotation += 0.2;
        const nsd = sunPos.normalize();
        const sun_dir: [3]f32 = .{ nsd.x, nsd.y, nsd.z };
        raylib.setShaderValue(earth.getShader(), loc_sundir, &sun_dir, .vec3);
        const cam_pos: [3]f32 = .{ camera.position.x, camera.position.y, camera.position.z };
        raylib.setShaderValue(earth.getShader(), loc_campos, &cam_pos, .vec3);

        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(.black);
        {
            camera.begin();
            defer camera.end();

            {
                gl.rlDisableBackfaceCulling();
                defer gl.rlEnableBackfaceCulling();

                skybox.draw(earthPos, 1, .gray);
            }

            {
                gl.rlPushMatrix();
                defer gl.rlPopMatrix();

                gl.rlRotatef(23.5, 1, 0, 0);

                raylib.drawCircle3D(earthPos, earth.radius.val() * 1.5, X, 0, .gray);

                {
                    gl.rlPushMatrix();
                    defer gl.rlPopMatrix();

                    gl.rlRotatef(-earthRotation, 0, 0, 1);

                    camera.position = earthPos.add(cameraOffset).transform(gl.rlGetMatrixTransform());
                    camera.up = Z.transform(gl.rlGetMatrixTransform());

                    drawVector(X.scale(10), .white);
                    drawVector(Y.scale(10), .red);
                    drawVector(Z.scale(10), .green);
                    earth.model.draw(earthPos, 1, .white);
                }
            }

            raylib.drawCircle3D(earthPos, earth.radius.val() * 2, X, 0, .dark_gray);
            raylib.drawCircle3D(earthPos, earth.radius.val() * 3, X, 0, .dark_gray);
            raylib.drawCircle3D(earthPos, earth.radius.val() * 4, X, 0, .dark_gray);

            {
                gl.rlPushMatrix();
                defer gl.rlPopMatrix();

                gl.rlRotatef(sunRotation, 0, 0, 1);

                gl.rlTranslatef(0, 500, 0);
                raylib.drawSphere(Vector3.zero(), 695_700 * 500 / 149_600_000, .white); // get the right angular size with a reasonable distance
                sunPos = Vector3.zero().transform(gl.rlGetMatrixTransform());
            }
        }
    }
}
