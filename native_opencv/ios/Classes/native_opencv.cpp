#include <opencv2/opencv.hpp>
#include <chrono>

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32)
#define IS_WIN32
#endif

#ifdef __ANDROID__
#include <android/log.h>
#endif

#ifdef IS_WIN32
#include <windows.h>
#endif

#if defined(__GNUC__)
    // Attributes to prevent 'unused' function from being removed and to make it visible
    #define FUNCTION_ATTRIBUTE __attribute__((visibility("default"))) __attribute__((used))
#elif defined(_MSC_VER)
    // Marking a function for export
    #define FUNCTION_ATTRIBUTE __declspec(dllexport)
#endif

using namespace cv;
using namespace std;

long long int get_now() {
    return chrono::duration_cast<std::chrono::milliseconds>(
            chrono::system_clock::now().time_since_epoch()
    ).count();
}

void platform_log(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
#ifdef __ANDROID__
    __android_log_vprint(ANDROID_LOG_VERBOSE, "ndk", fmt, args);
#elif defined(IS_WIN32)
    char *buf = new char[4096];
    std::fill_n(buf, 4096, '\0');
    _vsprintf_p(buf, 4096, fmt, args);
    OutputDebugStringA(buf);
    delete[] buf;
#else
    vfprintf(stderr,fmt, args);
#endif
    va_end(args);
}

// Avoiding name mangling
extern "C" {
    FUNCTION_ATTRIBUTE
    const char* version() {
        return CV_VERSION;
    }

    FUNCTION_ATTRIBUTE
    void process_image(char* inputImagePath, char* outputImagePath) {
        long long start = get_now();
        
        Mat input = imread(inputImagePath);
        Mat grey_image;
        
        cvtColor(input,grey_image,COLOR_BGR2GRAY);
        
        imwrite(outputImagePath, grey_image);
        
        int evalInMillis = static_cast<int>(get_now() - start);
        platform_log("Processing done in %dms\n", evalInMillis);
    }

    FUNCTION_ATTRIBUTE
    int cvtColor(int inBytesCount,uchar *rawBytes, uchar **encodedOutput) {
        vector<uchar> buf;
        vector<uint8_t> buffer(rawBytes, rawBytes + inBytesCount);
        long long start = get_now();
        Mat img = imdecode(buffer, IMREAD_COLOR);
        Mat grey_image;
        
        cvtColor(img,grey_image,COLOR_BGR2GRAY);
        imencode(".png", grey_image, buf); // save output into buf. Note that Dart Image.memory can process either .png or .jpg, which is why we're doing this encoding
        int evalInMillis = static_cast<int>(get_now() - start);
        platform_log("cvtColor done in %dms\n", evalInMillis);
        *encodedOutput = (unsigned char *) malloc(buf.size());
        memcpy(*encodedOutput, buf.data(), buf.size());
        
        return (int) buf.size();
    }
    
}
