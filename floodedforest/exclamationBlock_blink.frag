//Credit to Hoeloe for making this shader

#version 120
uniform sampler2D iChannel0;
uniform float brightness;

//Do your per-pixel shader logic here.
void main()
{
	vec4 c = texture2D(iChannel0, gl_TexCoord[0].xy);
	
	gl_FragColor = c * gl_Color;
	gl_FragColor = mix(gl_FragColor, vec4(1), brightness * gl_FragColor.a);
}