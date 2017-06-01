#version 120

/*



			███████ ███████ ███████ ███████ █
			█          █    █     █ █     █ █
			███████    █    █     █ ███████ █
			      █    █    █     █ █       
			███████    █    ███████ █       █

	Before you change anything here, please notice that you
	are allowed to modify my shaderpack ONLY for yourself!

	Please read my agreement for more informations!
		- http://bit.ly/1De7OOY

		
		
*/

//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;











//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {
	
	gl_Position = ftransform();
	
	color = gl_Color;
	
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	gl_FogFragCoord = gl_Position.z;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	
}