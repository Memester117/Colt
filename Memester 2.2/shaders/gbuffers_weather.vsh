#version 120

/*

	##########	##########	##########	##########	##
	##				##		##		##	##		##	##
	##				##		##		##	##		##	##
	##########		##		##		##	##########	##
			##		##		##		##	##			##
			##		##		##		##	##	
	##########		##		##########	##			##

Before you do anything here, make sure you've read my agreement!

Otherwise, notice that you are ONLY allowed to modify my shaderpack
for your OWN USE!

*/

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

void main() {
	gl_Position = ftransform();
	
	color = gl_Color;
	
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
}