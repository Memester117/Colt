#version 120

#define OVERDRAW 1.0

varying vec4 texcoord;

uniform int worldTime;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

void main() {
	gl_Position = ftransform();

	float timePow = 3.0;
	float timefract = worldTime;

	timeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 6000.0)/6000.0));
	timeNoon     = ((clamp(timefract, 0.0, 6000.0)) / 6000.0) - ((clamp(timefract, 6000.0, 12000.0) - 6000.0) / 6000.0);
	timeSunset   = ((clamp(timefract, 6000.0, 12000.0) - 6000.0) / 6000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
	timeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

	timeSunrise  = pow(timeSunrise, timePow);
	timeNoon     = pow(timeNoon, 1.0/timePow);
	timeSunset   = pow(timeSunset, timePow);
	timeMidnight = pow(timeMidnight, 1.0/timePow);

	texcoord = gl_MultiTexCoord0;

	texcoord = texcoord * 2.0 - 1.0;
	texcoord /= OVERDRAW;
	texcoord = texcoord * 0.5 + 0.5;
}
