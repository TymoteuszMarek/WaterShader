#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
    float4 backedGI : TEXCOORD1;
};

struct Interpolators
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float4 positionOS : TEXCOORD1;
    
    float2 uv : TEXCOORD2;
    
    float3 normalWS : TEXCOORD3;
    
    float4 backedGI : TEXCOORD4;
   
    float fogFactor : TEXCOORD5;
    
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
};

float CalculateWave(float2 uv, float scale, float amplitude)
{
    float wave = sin(uv.x * scale) * amplitude;

    return wave;
}

float4 ApplyWaves(float4 positionOS)
{
    float3 position = positionOS.xyz;
    
    float wave = CalculateWave(position.xz, 30.0, 0.1);
    float3 result = position + float3(0, wave, 0);
    
    return float4(result, 1);
}

float3 CalculateNormal(float3 positionOS)
{
    float3 position = positionOS.xyz;
    position = position + float3(0, CalculateWave(position.xz, 30.0, 0.1), 0);
    
    float3 forward = position + float3(0, 0, 0); 
    forward += float3(0, CalculateWave(forward.xz, 30.0, 1.0), 0);
    float3 forwardDir = forward - position;
    
    float3 side = position + float3(0, 0, 0);
    side += float3(0, CalculateWave(side.xz, 30.0, 1.0), 0);
    float3 sideDir = side - position;
    
    float3 normal = normalize(cross(forward, side));

    return normal;
}

Interpolators Vertex(Attributes i)
{
    Interpolators o;
    
    VertexPositionInputs posnInputs = GetVertexPositionInputs(ApplyWaves(i.positionOS));
    VertexNormalInputs normInputs = GetVertexNormalInputs(i.normalOS);
    
    o.positionCS = posnInputs.positionCS;
    o.positionWS = posnInputs.positionWS;
    o.uv = i.uv;
    o.normalWS = normInputs.normalWS;
    
    OUTPUT_LIGHTMAP_UV(i.backedGI, unity_LightmapST, o.lightmapUV);
    OUTPUT_SH(o.normalWS, o.vertexSH);
    
    o.fogFactor = ComputeFogFactor(o.positionCS.z);
    
    return o;
}

float4 _Color;
float _Glossiness;
float _Metallic;

float3 Fragment(Interpolators i) : SV_TARGET
{
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
    i.normalWS = normalize(i.normalWS);
    
    i.normalWS = CalculateNormal(i.positionWS);
    
    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = i.positionWS;
    lightingInput.normalWS = i.normalWS;
    lightingInput.viewDirectionWS = viewDir;
    lightingInput.shadowCoord = TransformWorldToShadowCoord(i.positionWS);
    lightingInput.fogCoord = i.fogFactor;
    lightingInput.bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);
    
    SurfaceData surfaceInput = (SurfaceData)0;
    surfaceInput.albedo = saturate(i.normalWS);
    surfaceInput.smoothness = _Glossiness;
    surfaceInput.metallic = _Metallic;
    surfaceInput.occlusion = 1;
    
    float4 lightingOutput = UniversalFragmentPBR(lightingInput, surfaceInput);
    
    return lightingOutput.rgb;
}