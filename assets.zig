const assets = @import("assets");

pub const texture = struct {
    pub const earth = struct {
        pub const day = @embedFile(assets.textures ++ "/earth_daymap.jpg");
        pub const night = @embedFile(assets.textures ++ "/earth_nightmap.jpg");
        pub const specular = @embedFile(assets.textures ++ "/earth_specular_map.jpg");
        pub const clouds = @embedFile(assets.textures ++ "/earth_clouds.jpg");
    };
};

pub const shader = struct {
    pub const earth = struct {
        //pub const vertex = @embedFile(assets.shaders ++ "/earth.vert");
        pub const fragment = @embedFile(assets.shaders ++ "/earth.frag");
    };
};

pub const icon = @embedFile(assets.icon);
