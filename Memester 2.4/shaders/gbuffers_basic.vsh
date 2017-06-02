#version 120








/*

                                      █████████   ███████████   ████████████   ██████████   ██
									  █████████   ███████████   ████████████   ██████████   ██
                                      ██               ██       ██        ██   ██      ██   ██
                                      ██               ██       ██        ██   ██      ██   ██
                                      █████████        ██       ██        ██   ██████████   ██
									  █████████        ██       ██        ██   ██████████   ██
                                             ██        ██       ██        ██   ██           ██
	                                         ██        ██       ██        ██   ██           
                                      █████████        ██       ████████████   ██           ██
									  █████████        ██       ████████████   ██           ██

                                           Stop doing anything! Read first the agreement!
										   
                                Please read this agreement carefully:

                                      • You are allowed to make videos or pictures with my shaderpack.
                                      • You are allowed to modify it ONLY for yourself!
                                      • If you donated me, please DON’T share my MediaFire link!
                                      • You are not allowed to claim my shaderpack as your own!
                                      • You are not allowed to redistribute it!
                                      • If you like to share my shaderpack, please share ONLY the dedelner.net link!
                                      • You are not allowed to publish your modifications!
                                      • You are not allowed to reupload it!
                                      • You are not allowed to earn money with it!
									  
                                For YouTube:
                                      • You are allowed to earn money with my shaderpack in your YouTube video.
                                      • If you modified something or use my development shaderpacks, please say that in your YouTube Video or description.

                                Please consider my agreement.
                                    - Thank you.
									
								Last change at: 23. August 2014


*/











varying vec4 color;
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {

	gl_Position = ftransform();
	
	color = gl_Color;
	
	gl_FogFragCoord = gl_Position.z;
	
}