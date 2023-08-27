Shader "Tao/SkyBox/云"
{
    Properties
    {
        [Header(Sky)][Space]
        _SkyColor("SkyColor", Color) = (0.2, 0.5, 0.85, 1)

        [Header(Ground)][Space]
        _GroundColor("GroundColor", Color) = (0.7, 0.75, 0.85, 1)

        [Header(Sun)][Space]
        _SunColor("SunColor", Color) = (1.0, 0.8, 0.6, 1)

        [Header(Cloud)][Space]
        _LightCloudColor("LightCloudColor", Color) = (1, 1, 1, 1)
        _DarkCloudColor("DarkCloudColor", Color) = (0.4, 0.4, 0.4, 1)
        _Step("Step", Range(0, 0.1)) = 0.05
        _Length("Length", Range(10, 50)) = 20
        _Height("Height", float) = 10000
        _CloudAlpha("CloudAlpha", Range(0, 1)) = 0.2
        _CloudSize("CloudSize", Range(0, 0.8)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType" = "Background" "Queue" = "Background" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 vertex : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _SkyColor;

            float4 _GroundColor;

            float4 _SunColor;

            float4 _LightCloudColor;
            float4 _DarkCloudColor;
            float4x4 _FourRay;
            float _Step;
            float _Length;
            float _Height;
            float _CloudAlpha;
            float _CloudSize;

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.vertex = normalize(v.vertex);
                return o;
            }

            // 云散列哈希
            float CloudHash (float3 st)
            {
                return frac(sin(dot(st, float3(12.989, 78.233, 46.157))) * 43758.5453123);
            }

            // 云噪声
            float CloudNoise (float3 st)
            {
                float3 i = floor(st);
                float3 f = frac(st);

                // 计算出8个点, 组成一个单位为1正方体
                float a0 = CloudHash(i);
                float a1 = CloudHash(i + float3(1.0, 0.0, 0.0));
                float a2 = CloudHash(i + float3(0.0, 1.0, 0.0));
                float a3 = CloudHash(i + float3(1.0, 1.0, 0.0));
                float a4 = CloudHash(i + float3(0.0, 0.0, 1.0));
                float a5 = CloudHash(i + float3(1.0, 0.0, 1.0));
                float a6 = CloudHash(i + float3(0.0, 1.0, 1.0));
                float a7 = CloudHash(i + float3(1.0, 1.0, 1.0));

                // 进行立方体插值
                float3 u = f * f * (3.0 - 2.0 * f);
                float b1 = lerp(a0, a1, u.x) + (a2 - a0) * u.y * (1.0 - u.x) + (a3 - a1) * u.x * u.y;
                float b2 = lerp(a4, a5, u.x) + (a6 - a4) * u.y * (1.0 - u.x) + (a7 - a5) * u.x * u.y;
                float noise = lerp(b1, b2, u.z);
                return noise;
            }

            // 云噪声(一朵一朵互相分离)
            float CloudValue(float3 st)
            {
                float alpha = CloudNoise(st * 0.1);
                float size = 1 - _CloudSize;
                alpha = smoothstep(size - 0.1, size + 0.1, alpha);
                // return alpha;
                // return CloudNoise(st);
                return CloudNoise(st) * alpha;
            }

            // 云分型
            float Cloudfbm(float3 st)
            {
                float3 ray = st / st.y;
                st.xz /= st.y;
                st.y = _Height + CloudValue(ray);
                float value = 0.0;
                float s = 1.0 / _Length;
                for (int i = 0; i < _Length; i++)
                {
                    float3 pos = st + i*_Step * ray + float3(0, 0.4, 1) * _Time.y;
                    float v = CloudValue(pos);
                    value += s * v;
                }
                return clamp(value, 0, 1);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 rd = normalize(i.vertex);

                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float4 finalColor = float4(0, 0, 0, 1);

                // cloud
                float cloudNoise = Cloudfbm(rd);
                float3 cloudColor = lerp(_LightCloudColor.xyz, _DarkCloudColor.xyz, pow(cloudNoise, 2));
                cloudColor = lerp(_DarkCloudColor.xyz, cloudColor, smoothstep(-0.16, 0.16, rd.y));
                cloudNoise = smoothstep(0.0, 0.6, cloudNoise);

                // sun
                float sundot = clamp(dot(rd, lightDir), 0.0, 1.0);
                float3 sunColor = 200 * _SunColor * clamp(pow(sundot, 16.0), 0, 1);
                sunColor += 400 * _SunColor * clamp(pow(sundot, 23.0), 0, 1);
                sunColor += 8000 * _SunColor * clamp(pow(sundot, 30.0), 0, 1);
                // skycolor
                float3 skyColor = _SkyColor * 1.1 - rd.y * rd.y * 0.5;
                skyColor = lerp(skyColor, 0.85 * _GroundColor, pow(1.0 - max(rd.y, 0.0), 4.0));
                skyColor += sunColor;
                // skydown
                float3 sky = lerp(skyColor, cloudColor, smoothstep(0, 0.16, cloudNoise * rd.y));
                sky = lerp(skyColor, sky, smoothstep(-0.1, 0.25, rd.y));

                return float4(sky, 1.0);
            }
            ENDCG
        }
    }
}
