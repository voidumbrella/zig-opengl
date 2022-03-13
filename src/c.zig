pub usingnamespace @cImport({
    @cDefine("STB_IMAGE_IMPLEMENTATION", {});
    @cDefine("STBI_ONLY_JPEG", {});
    @cDefine("STBI_ONLY_PNG", {});
    @cDefine("STBI_NO_SIMD", {});
    @cInclude("stb_image.h");

    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});
