/*
 * function: kernel_retinex
 * input:    image2d_t as read only
 * output:   image2d_t as write only
 */
typedef struct {
    float    gain;
    float    threshold;
    float    log_min;
    float    log_max;
    float    width;
    float    height;
} CLRetinexConfig;

__constant float log_table[256] = {
    0.000000, 0.693147, 1.098612, 1.386294, 1.609438, 1.791759, 1.945910, 2.079442,
    2.197225, 2.302585, 2.397895, 2.484907, 2.564949, 2.639057, 2.708050, 2.772589,
    2.833213, 2.890372, 2.944439, 2.995732, 3.044522, 3.091042, 3.135494, 3.178054,
    3.218876, 3.258097, 3.295837, 3.332205, 3.367296, 3.401197, 3.433987, 3.465736,
    3.496508, 3.526361, 3.555348, 3.583519, 3.610918, 3.637586, 3.663562, 3.688879,
    3.713572, 3.737670, 3.761200, 3.784190, 3.806662, 3.828641, 3.850148, 3.871201,
    3.891820, 3.912023, 3.931826, 3.951244, 3.970292, 3.988984, 4.007333, 4.025352,
    4.043051, 4.060443, 4.077537, 4.094345, 4.110874, 4.127134, 4.143135, 4.158883,
    4.174387, 4.189655, 4.204693, 4.219508, 4.234107, 4.248495, 4.262680, 4.276666,
    4.290459, 4.304065, 4.317488, 4.330733, 4.343805, 4.356709, 4.369448, 4.382027,
    4.394449, 4.406719, 4.418841, 4.430817, 4.442651, 4.454347, 4.465908, 4.477337,
    4.488636, 4.499810, 4.510860, 4.521789, 4.532599, 4.543295, 4.553877, 4.564348,
    4.574711, 4.584967, 4.595120, 4.605170, 4.615121, 4.624973, 4.634729, 4.644391,
    4.653960, 4.663439, 4.672829, 4.682131, 4.691348, 4.700480, 4.709530, 4.718499,
    4.727388, 4.736198, 4.744932, 4.753590, 4.762174, 4.770685, 4.779123, 4.787492,
    4.795791, 4.804021, 4.812184, 4.820282, 4.828314, 4.836282, 4.844187, 4.852030,
    4.859812, 4.867534, 4.875197, 4.882802, 4.890349, 4.897840, 4.905275, 4.912655,
    4.919981, 4.927254, 4.934474, 4.941642, 4.948760, 4.955827, 4.962845, 4.969813,
    4.976734, 4.983607, 4.990433, 4.997212, 5.003946, 5.010635, 5.017280, 5.023881,
    5.030438, 5.036953, 5.043425, 5.049856, 5.056246, 5.062595, 5.068904, 5.075174,
    5.081404, 5.087596, 5.093750, 5.099866, 5.105945, 5.111988, 5.117994, 5.123964,
    5.129899, 5.135798, 5.141664, 5.147494, 5.153292, 5.159055, 5.164786, 5.170484,
    5.176150, 5.181784, 5.187386, 5.192957, 5.198497, 5.204007, 5.209486, 5.214936,
    5.220356, 5.225747, 5.231109, 5.236442, 5.241747, 5.247024, 5.252273, 5.257495,
    5.262690, 5.267858, 5.273000, 5.278115, 5.283204, 5.288267, 5.293305, 5.298317,
    5.303305, 5.308268, 5.313206, 5.318120, 5.323010, 5.327876, 5.332719, 5.337538,
    5.342334, 5.347108, 5.351858, 5.356586, 5.361292, 5.365976, 5.370638, 5.375278,
    5.379897, 5.384495, 5.389072, 5.393628, 5.398163, 5.402677, 5.407172, 5.411646,
    5.416100, 5.420535, 5.424950, 5.429346, 5.433722, 5.438079, 5.442418, 5.446737,
    5.451038, 5.455321, 5.459586, 5.463832, 5.468060, 5.472271, 5.476464, 5.480639,
    5.484797, 5.488938, 5.493061, 5.497168, 5.501258, 5.505332, 5.509388, 5.513429,
    5.517453, 5.521461, 5.525453, 5.529429, 5.533389, 5.537334, 5.541264, 5.545177
};

__kernel void kernel_retinex (__read_only image2d_t input, __read_only image2d_t ga_input, __write_only image2d_t output, uint vertical_offset_in, uint vertical_offset_out, CLRetinexConfig re_config)
{
    int x = get_global_id (0);
    int y = get_global_id (1);
    sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;
    sampler_t sampler1 = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;

    float4 y_out, uv_in;
    float4 y_in, y_ga;
    float y_lg;
    int i;
    // cpy UV
    if(y % 2 == 0) {
        uv_in = read_imagef(input, sampler, (int2)(x, y / 2 + vertical_offset_in));
        write_imagef(output, (int2)(x, y / 2 + vertical_offset_out), uv_in);
    }

    y_in = read_imagef(input, sampler, (int2)(x, y)) * 255.0;
    y_ga = read_imagef(ga_input, sampler1, (float2)(x / re_config.width, y / (re_config.height / 2 * 3))) * 255.0;

    y_lg = log_table[convert_int(y_in.x)] - log_table[convert_int(y_ga.x)];

    y_out.x = re_config.gain * y_in.x / 128.0 * (y_lg - re_config.log_min) / 255.0;
    write_imagef(output, (int2)(x, y), y_out);
}
