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

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

void main() {

/* DRAWBUFFERS:7 */

	gl_FragData[0] = texture2D(texture, texcoord.st) * color;
	gl_FragData[1] = vec4(0.0);
		
}