/*
 * function: kernel_yuv_pipe
 * input:    image2d_t as read only
 * output:   image2d_t as write only
 */
unsigned int get_sector_id (float u, float v)
{
    if ((u >= 0.0) && (v >= 0.0 ))
    {
        if (v / u <= 0.5)
            return 0;
        else if ((v / u > .05) && (v / u <= 1.0))
            return 1;
        else if ((v / u > 1.0) && (v / u <= 2.0))
            return 2;
        else
            return 3;
    }
    else if ((u < 0.0) && (v >= 0.0))
    {
        if (v / u <= -2.0)
            return 4;
        if ((v / u > -2.0) && (v / u <= -1.0))
            return 5;
        if ((v / u > -1.0) && (v / u <= -0.5))
            return 6;
        else
            return 7;
    }
    else if ((u < 0.0) && (v <= 0.0))
    {
        if (v / u <= 0.5)
            return 8;
        else if ((v / u > 0.5) && (v / u <= 1.0))
            return 9;
        else if ((v / u > 1.0) && (v / u <= 2.0))
            return 10;
        else
            return 11;
    }
    else
    {
        if(v / u <= -2.0)
            return 12;
        else if((v / u > -2.0) && (v / u <= -1.0))
            return 13;
        else if((v / u > -1.0) && (v / u <= -0.5))
            return 14;
        else
            return 15;
    }
}

__inline void cl_csc_rgbatonv12(float4 *in, float *out, __global float *matrix)
{

    (*out) = matrix[0] * (*in).x + matrix[1] * (*in).y + matrix[2] * (*in).z;
    (*(out + 1)) = matrix[0] * (*(in + 1)).x + matrix[1] * (*(in + 1)).y + matrix[2] * (*(in + 1)).z;
    (*(out + 2)) = matrix[0] * (*(in + 2)).x + matrix[1] * (*(in + 2)).y + matrix[2] * (*(in + 2)).z;
    (*(out + 3)) = matrix[0] * (*(in + 3)).x + matrix[1] * (*(in + 3)).y + matrix[2] * (*(in + 3)).z;
    (*(out + 4)) = matrix[3] * (*in).x + matrix[4] * (*in).y + matrix[5] * (*in).z;
    (*(out + 5)) = matrix[6] * (*in).x + matrix[7] * (*in).y + matrix[8] * (*in).z;
}

__inline void cl_macc(float *in, __global float *table)
{
    unsigned int table_id;
    float ui, vi, uo, vo;
    ui = (*in);
    vi = (*(in + 1));
    table_id = get_sector_id(ui, vi);

    uo = ui * table[4 * table_id] + vi * table[4 * table_id + 1];
    vo = ui * table[4 * table_id + 2] + vi * table[4 * table_id + 3];

    (*in) = uo + 0.5;
    (*(in + 1)) = vo + 0.5;
}

__kernel void kernel_yuv_pipe (__read_only image2d_t input, __write_only image2d_t output, uint vertical_offset, __global float *matrix, __global float *table)
{
    int x = get_global_id (0);
    int y = get_global_id (1);
    sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_NONE | CLK_FILTER_NEAREST;

    float4 p_in[4];
    float p_out[6];

    p_in[0] = read_imagef(input, sampler, (int2)(2 * x, 2 * y));
    p_in[1] = read_imagef(input, sampler, (int2)(2 * x + 1, 2 * y));
    p_in[2] = read_imagef(input, sampler, (int2)(2 * x, 2 * y + 1));
    p_in[3] = read_imagef(input, sampler, (int2)(2 * x + 1, 2 * y + 1));

    cl_csc_rgbatonv12(&p_in[0], &p_out[0], matrix);
    cl_macc(&p_out[4], table);

    write_imagef(output, (int2)(2 * x, 2 * y), (float4)p_out[0]);
    write_imagef(output, (int2)(2 * x + 1, 2 * y), (float4)p_out[1]);
    write_imagef(output, (int2)(2 * x, 2 * y + 1), (float4)p_out[2]);
    write_imagef(output, (int2)(2 * x + 1, 2 * y + 1), (float4)p_out[3]);
    write_imagef(output, (int2)(2 * x, y + vertical_offset), (float4)p_out[4]);
    write_imagef(output, (int2)(2 * x + 1, y + vertical_offset), (float4)p_out[5]);
}

