Shader "CubedParadox/Flat Lit Toon MMD Full"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_ColorMask("ColorMask", 2D) = "black" {}
		_SphereAddTex("Sphere Add Texture", 2D) = "black" {}
		_SphereAddIntensity("Add Sphere Texture Intensity", Range(0, 5)) = 1.0
		_SphereMulTex("Sphere Multiply Texture", 2D) = "white" {}
		_SphereMulIntensity("Multiply Sphere Texture Intensity", Range(0, 5)) = 1.0
		_ToonTex("Toon Texture", 2D) = "white" {}
		_outline_width("outline_width", Float) = 0.2
		_outline_color("outline_color", Color) = (0.5,0.5,0.5,1)
		_outline_tint("outline_tint", Range(0, 1)) = 0.5
		_EmissionMap("Emission Map", 2D) = "white" {}
		[HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)
		_BumpMap("BumpMap", 2D) = "bump" {}
		_Cutoff("Alpha cutoff", Range(0,1)) = 0.5

		// Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _OutlineMode("__outline_mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
	}

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
		}

		Pass
		{

			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM
			#include "FlatLitToonCore MMD.cginc"
			#pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			float4 frag(VertexOutput i) : COLOR
			{
				float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				i.normalDir = normalize(i.normalDir);
				float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
				float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(i.uv0, _BumpMap)));
				float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals
				float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));
				
				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				float3 lightColor = _LightColor0.rgb;
				UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);

				float4 _EmissionMap_var = tex2D(_EmissionMap,TRANSFORM_TEX(i.uv0, _EmissionMap));
				float3 emissive = (_EmissionMap_var.rgb*_EmissionColor.rgb);
				float4 _ColorMask_var = tex2D(_ColorMask,TRANSFORM_TEX(i.uv0, _ColorMask));
				float4 baseColor = lerp((_MainTex_var.rgba*_Color.rgba),_MainTex_var.rgba,_ColorMask_var.r);
				baseColor *= float4(i.col.rgb, 1);

				// MMD Spheres
				float3 viewNormal = normalize(mul((float3x3)UNITY_MATRIX_V, normalDirection));
				float2 sphereUV = viewNormal.xy * 0.5 + 0.5;
				float4 sphereAdd = tex2D(_SphereAddTex, sphereUV);
				sphereAdd.rgb *= _SphereAddIntensity;
				float4 sphereMul = tex2D(_SphereMulTex, sphereUV);
				sphereMul.rgb *= _SphereMulIntensity;

				#if COLORED_OUTLINE
				if(i.is_outline) 
				{
					baseColor.rgb = i.col.rgb; 
					sphereAdd = 0;
					sphereMul = 1;
				}
				#endif

				#if defined(_ALPHATEST_ON)
        		clip (baseColor.a - _Cutoff);
    			#endif
				
				float3 lightmap = float4(1.0,1.0,1.0,1.0);
				#ifdef LIGHTMAP_ON
				lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1 * unity_LightmapST.xy + unity_LightmapST.zw));
				#endif

				float3 reflectionMap = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normalize((_WorldSpaceCameraPos - objPos.rgb)), 7), unity_SpecCube0_HDR)* 0.02;

				float grayscalelightcolor = dot(_LightColor0.rgb, grayscale_vector);
				float bottomIndirectLighting = grayscaleSH9(float3(0.0, -1.0, 0.0));
				float topIndirectLighting = grayscaleSH9(float3(0.0, 1.0, 0.0));

				normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); 

				float grayscaleDirectLighting = dot(lightDirection, normalDirection)*grayscalelightcolor*attenuation + grayscaleSH9(normalDirection);

				float lightDifference = topIndirectLighting + grayscalelightcolor - bottomIndirectLighting;
				float remappedLight = (grayscaleDirectLighting - bottomIndirectLighting) / lightDifference;

				float3 indirectLighting = saturate((ShadeSH9(half4(0.0, -1.0, 0.0, 1.0)) + reflectionMap));
				float3 directLighting = saturate((ShadeSH9(half4(0.0, 1.0, 0.0, 1.0)) + reflectionMap + _LightColor0.rgb));
				float3 directContribution = saturate((1.0 - 0.0) + floor(saturate(remappedLight) * 2.0));

				float4 toonTexColor = tex2D(_ToonTex, float2(0.5, dot(lightDirection, normalDirection) * 0.5 + 0.5));
				float3 finalColor = emissive + (baseColor * sphereMul + sphereAdd) * lerp(indirectLighting, directLighting, saturate(directContribution * toonTexColor));

				fixed4 finalRGBA = fixed4(finalColor * lightmap, baseColor.a);
				UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
				return finalRGBA;
			}
			ENDCG
		}

		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Blend [_SrcBlend] One

			CGPROGRAM
			#pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#include "FlatLitToonCore MMD.cginc"
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog

			float4 frag(VertexOutput i) : COLOR
			{
				float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				i.normalDir = normalize(i.normalDir);
				float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
				float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(i.uv0, _BumpMap)));
				float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals
				float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));

				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				float3 lightColor = _LightColor0.rgb;
				UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);
	
				float4 _ColorMask_var = tex2D(_ColorMask,TRANSFORM_TEX(i.uv0, _ColorMask));
				float4 baseColor = lerp((_MainTex_var.rgba*_Color.rgba),_MainTex_var.rgba,_ColorMask_var.r);
				baseColor *= float4(i.col.rgb, 1);

				// MMD Spheres
				float3 viewNormal = normalize(mul((float3x3)UNITY_MATRIX_V, normalDirection));
				float2 sphereUV = viewNormal.xy * 0.5 + 0.5;
				float4 sphereAdd = tex2D(_SphereAddTex, sphereUV);
				sphereAdd.rgb *= _SphereAddIntensity;
				float4 sphereMul = tex2D(_SphereMulTex, sphereUV);
				sphereMul.rgb *= _SphereMulIntensity;

				#if COLORED_OUTLINE
				if(i.is_outline) {
					baseColor.rgb = i.col.rgb;
					sphereAdd = 0;
					sphereMul = 1;
				}
				#endif

				#if defined(_ALPHATEST_ON)
        		clip (baseColor.a - _Cutoff);
    			#endif

    			float lightContribution = dot(normalize(_WorldSpaceLightPos0.xyz - i.posWorld.xyz),normalDirection)*attenuation;
				float3 directContribution = floor(saturate(lightContribution) * 2.0);

				float4 toonTexColor = tex2D(_ToonTex, float2(0.5, dot(lightDirection, normalDirection) * 0.5 + 0.5));
				float3 finalColor = (baseColor * sphereMul + sphereAdd) * lerp(0, _LightColor0.rgb, saturate(directContribution * toonTexColor + attenuation));
				fixed4 finalRGBA = fixed4(finalColor,1) * i.col;
				UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
				return finalRGBA;
			}
			ENDCG
		}

		Pass
		{
			Name "SHADOW_CASTER"
			Tags{ "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual

			CGPROGRAM
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#include "FlatLitToonShadows.cginc"
			
			#pragma multi_compile_shadowcaster

			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster
			ENDCG
		}
	}
	FallBack "Diffuse"
	CustomEditor "FlatLitToonInspectorMMDFull"
}