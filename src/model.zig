const zmath = @import("zmath.zig");
const std = @import("std");
const gl = @import("gl");

const c = @import("c.zig");

const Shader = @import("shader.zig").Shader;

const Vertex = struct {
    position: zmath.Vec,
    normal: zmath.Vec,
    tex_coords: zmath.Vec,
};

const TextureType = enum {
    diffuse,
    specular,
};

const Texture = struct {
    tex: gl.Texture,
    type: TextureType,
};

fn loadMaterialTextures(allocator: std.mem.Allocator, material: c.aiMaterial, tex_type: TextureType) ![]Texture {
    var textures = std.ArrayList(Texture).init(allocator);
    defer textures.deinit();

    const t = @intCast(c_uint, switch (tex_type) {
        .diffuse => c.aiTextureType_DIFFUSE,
        .specular => c.aiTextureType_SPECULAR,
    });
    const tex_count = c.aiGetMaterialTextureCount(&material, t);

    var i: usize = 0;
    while (i < tex_count) : (i += 1) {
        var path: c.aiString = undefined;
        if (c.aiGetMaterialTexture(&material, t, @intCast(c_uint, i), &path, null, null, null, null, null, 0) != c.AI_SUCCESS) {
            return error.NoMaterial;
        }
        std.log.debug("Loading texture: {s}", .{path.data[0..path.length]});
        const tex = try loadTexture(path.data[0..path.length]);
        try textures.append(Texture{ .tex = tex, .type = .specular });
    }

    return textures.toOwnedSlice();
}

fn loadTexture(path: []const u8) !gl.Texture {
    const tex = gl.createTexture(.@"2d");
    var width: c_int = undefined;
    var height: c_int = undefined;
    var num_chans: c_int = undefined;
    c.stbi_set_flip_vertically_on_load(1);
    var data = c.stbi_load(path.ptr, &width, &height, &num_chans, 0) orelse return error.LoadFail;
    defer c.stbi_image_free(data);

    const format: gl.PixelFormat = switch (num_chans) {
        1 => .red,
        2 => .rg,
        3 => .rgb,
        4 => .rgba,
        else => {
            std.log.err("Unexpected number of channels: {}", .{num_chans});
            unreachable;
        },
    };
    tex.bind(.@"2d");
    gl.textureImage2D(.@"2d", 0, format, @intCast(usize, width), @intCast(usize, height), format, .unsigned_byte, data);
    gl.generateMipmap(.@"2d");

    gl.textureParameter(tex, .wrap_s, .repeat);
    gl.textureParameter(tex, .wrap_t, .repeat);
    gl.textureParameter(tex, .min_filter, .linear_mipmap_linear);
    gl.textureParameter(tex, .mag_filter, .linear);

    return tex;
}

pub const Model = struct {
    allocator: std.mem.Allocator,
    meshes: []Mesh,

    pub fn fromFile(allocator: std.mem.Allocator, path: []const u8) !Model {
        const scene_ptr = c.aiImportFile(path.ptr, c.aiProcess_Triangulate) orelse {
            std.log.err("aiImportFile: {s}", .{c.aiGetErrorString()});
            return error.ImportFail;
        };
        const scene = scene_ptr.*;
        if (scene.mFlags & c.AI_SCENE_FLAGS_INCOMPLETE != 0 or scene.mRootNode == null) return error.BadModel;

        var meshes = std.ArrayList(Mesh).init(allocator);
        defer meshes.deinit();
        try processNode(allocator, scene, scene.mRootNode.*, &meshes);

        return Model{
            .allocator = allocator,
            .meshes = meshes.toOwnedSlice(),
        };
    }

    pub fn draw(self: Model, shader: Shader) void {
        for (self.meshes) |mesh| {
            mesh.draw(shader);
        }
    }

    fn processNode(allocator: std.mem.Allocator, scene: c.aiScene, node: c.aiNode, mesh_list: *std.ArrayList(Mesh)) anyerror!void {
        if (node.mMeshes != null) {
            for (node.mMeshes[0..node.mNumMeshes]) |i| {
                const mesh = scene.mMeshes[i].*;
                try mesh_list.append(try processMesh(allocator, scene, mesh));
            }
        }
        if (node.mChildren != null) {
            for (node.mChildren[0..node.mNumChildren]) |child| {
                try processNode(allocator, scene, child.*, mesh_list);
            }
        }
    }

    fn processMesh(allocator: std.mem.Allocator, scene: c.aiScene, mesh: c.aiMesh) !Mesh {
        var vertices = std.ArrayList(Vertex).init(allocator);
        defer vertices.deinit();
        var indices = std.ArrayList(u32).init(allocator);
        defer indices.deinit();
        var textures = std.ArrayList(Texture).init(allocator);
        defer textures.deinit();

        for (mesh.mVertices[0..mesh.mNumVertices]) |vert| {
            try vertices.append(Vertex{
                .position = zmath.f32x4(vert.x, vert.y, vert.z, 0.0),
                .normal = zmath.f32x4s(0.0),
                .tex_coords = zmath.f32x4s(0.0),
            });
        }
        if (mesh.mNormals != null) {
            for (mesh.mNormals[0..mesh.mNumVertices]) |normal, i| {
                vertices.items[i].normal = zmath.f32x4(normal.x, normal.y, normal.z, 0.0);
            }
        }
        if (mesh.mTextureCoords[0] != null) {
            for (mesh.mTextureCoords[0][0..mesh.mNumVertices]) |tex_coord, i| {
                vertices.items[i].tex_coords = zmath.f32x4(tex_coord.x, tex_coord.y, tex_coord.z, 0.0);
            }
        }
        for (mesh.mFaces[0..mesh.mNumFaces]) |face| {
            for (face.mIndices[0..face.mNumIndices]) |i| {
                try indices.append(i);
            }
        }
        if (mesh.mMaterialIndex >= 0) {
            const material = scene.mMaterials[mesh.mMaterialIndex].*;
            const diffuse_maps = try loadMaterialTextures(allocator, material, .diffuse);
            const specular_maps = try loadMaterialTextures(allocator, material, .specular);
            try textures.appendSlice(diffuse_maps);
            try textures.appendSlice(specular_maps);
        }

        return Mesh.init(vertices.toOwnedSlice(), indices.toOwnedSlice(), textures.toOwnedSlice());
    }
};

pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,
    textures: []Texture,

    VAO: gl.VertexArray,
    VBO: gl.Buffer,
    EBO: gl.Buffer,

    pub fn init(vertices: []Vertex, indices: []u32, textures: []Texture) Mesh {
        const self = Mesh{
            .vertices = vertices,
            .indices = indices,
            .textures = textures,
            .VAO = gl.VertexArray.create(),
            .VBO = gl.Buffer.create(),
            .EBO = gl.Buffer.create(),
        };

        self.VAO.bind();
        self.VBO.bind(.array_buffer);
        gl.bufferData(.array_buffer, Vertex, self.vertices, .static_draw);
        self.EBO.bind(.element_array_buffer);
        gl.bufferData(.element_array_buffer, u32, self.indices, .static_draw);

        // Vertex positions
        gl.vertexAttribPointer(0, 3, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "position"));
        self.VAO.enableVertexAttribute(0);
        // Vertex normals
        gl.vertexAttribPointer(1, 3, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "normal"));
        self.VAO.enableVertexAttribute(1);
        // Texture coordinates
        gl.vertexAttribPointer(2, 2, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "tex_coords"));
        self.VAO.enableVertexAttribute(2);

        // Unbind
        return self;
    }

    pub fn draw(self: Mesh, shader: Shader) void {
        for (self.textures) |texture, i| {
            gl.activeTexture(@intToEnum(gl.TextureUnit, @enumToInt(gl.TextureUnit.texture_0) + i));
            const uniform_name =
                switch (texture.type) {
                .diffuse => "material.diffuse",
                .specular => "material.specular",
            };
            shader.uniformi32(uniform_name, @intCast(i32, i));
            texture.tex.bind(.@"2d");
        }
        gl.activeTexture(.texture_0);

        shader.uniformf32("material.shininess", 13.0);
        self.VAO.bind();
        gl.drawElements(.triangles, self.indices.len, .u32, 0);
    }
};
