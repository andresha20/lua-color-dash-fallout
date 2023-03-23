float red;
float green;
float blue;
float alpha;

technique simple
{
    pass P0
    {
        MaterialAmbient = float4(red,green,blue,alpha);
    }
}