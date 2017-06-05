module glad.gl.ext;


private import glad.gl.types;
private import glad.gl.enums;
private import glad.gl.funcs;
bool GL_ARB_sparse_texture;
bool GL_ARB_sparse_texture2;
bool GL_ARB_sparse_texture_clamp;
nothrow @nogc extern(System) {
alias fp_glTexPageCommitmentARB = void function(GLenum, GLint, GLint, GLint, GLint, GLsizei, GLsizei, GLsizei, GLboolean);
}
__gshared {
fp_glTexPageCommitmentARB glTexPageCommitmentARB;
}
