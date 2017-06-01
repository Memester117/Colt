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

varying vec4 texcoord;
varying vec3 lightVector;
varying float handItemLight;

uniform int worldTime;
uniform int heldItemId;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;











//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {
	
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}
	
	handItemLight = 0.0;
	if (heldItemId == 50) {
		// torch
		handItemLight = 0.5;
	} else if (heldItemId == 76 || heldItemId == 94) {
		// active redstone torch / redstone repeater
		handItemLight = 0.1;
	} else if (heldItemId == 89) {
		// lightstone
		handItemLight = 0.6;
	} else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51) {
		// lava / lava / fire
		handItemLight = 0.5;
	} else if (heldItemId == 91) {
		// jack-o-lantern
		handItemLight = 0.6;
	} else if (heldItemId == 327) {
		handItemLight = 0.2;
	}
	
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;

}
