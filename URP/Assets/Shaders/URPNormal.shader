﻿Shader "URP/URPNormal"
{
    Properties
    {
        _MainTex ("Base Texture", 2D) = "white" {}
        _BaseColor("Base Color",Color)=(1,1,1,1)
        _NormalTex("Normal",2D)="bump"{}
        _NormalScale("NormalScale",Range(0,1))=1
        _SpeluarRange("SpecularRange",Range(1,200))=50
        _SpeluarColor("SpecularColor",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        float4 _NormalTex_ST;
        half4 _BaseColor;
        half4 _SpeluarColor;
        half _NormalScale;
        half _SpeluarRange;
        CBUFFER_END

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
            float3 normalOS:NORMAL;
            float4 tangentOS:TANGENT;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;
            float4 uv : TEXCOORD0;//float4的uv（前两个用作漫反射纹理的偏移缩放,后两个用作法线纹理的偏移缩放)
            float4 tangentWS:TANGENT;//切线
            float4 normalWS:NORMAL;//双切线
            float4 bitangentWS:TEXCOORD1;//法线
            //切线，双切线，法线组成切线空间
        };

        TEXTURE2D(_MainTex);
        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_MainTex);
        SAMPLER(sampler_NormalTex);

        ENDHLSL

        Pass
        {        
            NAME"MainPass"
            Tags{
                "LightMode"="UniversalForward"
			}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v IN)
            {
                v2f OUT;
                //TRANSFORM_TEX 拿顶点的uv去和材质球的tiling和offset作运算 
                //相对于IN.uv.xy*_MainTex_ST.xy+_MainTex_ST.zw ,其中MainTex_ST.xy中是tiling,_MainTex_ST.zw中是offset
                OUT.uv.xy=TRANSFORM_TEX(IN.uv,_MainTex);
                OUT.uv.zw=TRANSFORM_TEX(IN.uv,_NormalTex);

                OUT.positionCS = TransformObjectToHClip(IN.positionOS);
                OUT.normalWS.xyz = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.tangentWS.xyz = normalize(TransformObjectToWorld(IN.tangentOS));
                //这里乘一个unity_WorldTransformParams.w是为判断是否使用了奇数相反的缩放
                OUT.bitangentWS.xyz = cross(OUT.normalWS.xyz,OUT.tangentWS.xyz)*IN.tangentOS.w*unity_WorldTransformParams.w;
                float3 positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.tangentWS.w = positionWS.x;
                OUT.bitangentWS.w = positionWS.y;
                OUT.normalWS.w = positionWS.z;
                return OUT;
            }

            float4 frag(v2f IN):SV_Target
            {
                float3 WSpos = float3(IN.tangentWS.w,IN.bitangentWS.w,IN.normalWS.w);
                float3x3 T2W = {IN.tangentWS.xyz,IN.bitangentWS.xyz,IN.normalWS.xyz};
                half4 nortex = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,IN.uv.zw);
                float3 normalTS = UnpackNormalScale(nortex,_NormalScale);
                normalTS.z = pow((1-pow(normalTS.x,2)-pow(normalTS.y,2)),0.5);//规范化法线
                float3 norWS = mul(normalTS,T2W);////注意这里是右乘T2W的，等同于左乘T2W的逆

                Light myLight = GetMainLight();
                float halfLambot = dot(norWS,normalize(myLight.direction))*0.5+0.5;
                half4 diff = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv.xy)*halfLambot*_BaseColor;
                float spe = dot(normalize(normalize(myLight.direction)+normalize(_WorldSpaceCameraPos-WSpos)),norWS);//计算高光
                spe = pow(spe,_SpeluarRange);

                return spe*_SpeluarColor+diff;
            }
            ENDHLSL  //ENDCG
        }
    }
}