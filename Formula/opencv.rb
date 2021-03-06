class Opencv < Formula
  desc "Open source computer vision library"
  homepage "https://opencv.org/"
  url "https://github.com/opencv/opencv/archive/4.1.0.tar.gz"
  sha256 "8f6e4ab393d81d72caae6e78bd0fd6956117ec9f006fba55fcdb88caf62989b7"

  bottle do
    sha256 "f7783a1f2e99c5bbe358e73a087e871e518e34b72761f5f99d7de042dbeacba0" => :mojave
    sha256 "d003d4bcd8d3038e38f1446e83270e912628342c68ff257a2c481c2a4f5f6165" => :high_sierra
    sha256 "2ebd51e12222d60c5724fe8a9b04fbfae9d9311ee9af192f39c5fd48d22a7782" => :sierra
  end

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "eigen"
  depends_on "ffmpeg"
  depends_on "harfbuzz"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "numpy"
  depends_on "openexr"
  depends_on "python"
  depends_on "python@2"
  depends_on "tbb"

  resource "contrib" do
    url "https://github.com/opencv/opencv_contrib/archive/4.1.0.tar.gz"
    sha256 "e7d775cc0b87b04308823ca518b11b34cc12907a59af4ccdaf64419c1ba5e682"
  end

  patch do
    url "https://github.com/opencv/opencv/pull/14308.patch?full_index=1"
    sha256 "9de405097cbafeadf0b980083edf1ff6b1a18e452bffea2b88a235c36677a1f8"
  end

  def install
    ENV.cxx11
    ENV.prepend_path "PATH", Formula["python@2"].opt_libexec/"bin"

    resource("contrib").stage buildpath/"opencv_contrib"

    # Reset PYTHONPATH, workaround for https://github.com/Homebrew/homebrew-science/pull/4885
    ENV.delete("PYTHONPATH")

    py2_prefix = `python2-config --prefix`.chomp
    py2_lib = "#{py2_prefix}/lib"

    py3_config = `python3-config --configdir`.chomp
    py3_include = `python3 -c "import distutils.sysconfig as s; print(s.get_python_inc())"`.chomp
    py3_version = Language::Python.major_minor_version "python3"

    args = std_cmake_args + %W[
      -DCMAKE_OSX_DEPLOYMENT_TARGET=
      -DBUILD_JASPER=OFF
      -DBUILD_JPEG=ON
      -DBUILD_OPENEXR=OFF
      -DBUILD_PERF_TESTS=OFF
      -DBUILD_PNG=OFF
      -DBUILD_TESTS=OFF
      -DBUILD_TIFF=OFF
      -DBUILD_ZLIB=OFF
      -DBUILD_opencv_hdf=OFF
      -DBUILD_opencv_java=OFF
      -DBUILD_opencv_text=ON
      -DOPENCV_ENABLE_NONFREE=ON
      -DOPENCV_EXTRA_MODULES_PATH=#{buildpath}/opencv_contrib/modules
      -DOPENCV_GENERATE_PKGCONFIG=ON
      -DWITH_1394=OFF
      -DWITH_CUDA=OFF
      -DWITH_EIGEN=ON
      -DWITH_FFMPEG=ON
      -DWITH_GPHOTO2=OFF
      -DWITH_GSTREAMER=OFF
      -DWITH_JASPER=OFF
      -DWITH_OPENEXR=ON
      -DWITH_OPENGL=OFF
      -DWITH_QT=OFF
      -DWITH_TBB=ON
      -DWITH_VTK=OFF
      -DBUILD_opencv_python2=ON
      -DBUILD_opencv_python3=ON
      -DPYTHON2_EXECUTABLE=#{which "python"}
      -DPYTHON2_LIBRARY=#{py2_lib}/libpython2.7.dylib
      -DPYTHON2_INCLUDE_DIR=#{py2_prefix}/include/python2.7
      -DPYTHON3_EXECUTABLE=#{which "python3"}
      -DPYTHON3_LIBRARY=#{py3_config}/libpython#{py3_version}.dylib
      -DPYTHON3_INCLUDE_DIR=#{py3_include}
    ]

    # The compiler on older Mac OS cannot build some OpenCV files using AVX2
    # extensions, failing with errors such as
    # "error: use of undeclared identifier '_mm256_cvtps_ph'"
    # Work around this by not trying to build AVX2 code.
    if MacOS.version <= :yosemite
      args << "-DCPU_DISPATCH=SSE4_1,SSE4_2,AVX"
    end

    args << "-DENABLE_AVX=OFF" << "-DENABLE_AVX2=OFF"
    unless MacOS.version.requires_sse42?
      args << "-DENABLE_SSE41=OFF" << "-DENABLE_SSE42=OFF"
    end

    mkdir "build" do
      system "cmake", "..", *args
      system "make"
      system "make", "install"
      system "make", "clean"
      system "cmake", "..", "-DBUILD_SHARED_LIBS=OFF", *args
      system "make"
      lib.install Dir["lib/*.a"]
      lib.install Dir["3rdparty/**/*.a"]
    end
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <opencv2/opencv.hpp>
      #include <iostream>
      int main() {
        std::cout << CV_VERSION << std::endl;
        return 0;
      }
    EOS
    system ENV.cxx, "-std=c++11", "test.cpp", "-I#{include}/opencv4",
                    "-o", "test"
    assert_equal `./test`.strip, version.to_s

    ["python2.7", "python3"].each do |python|
      output = shell_output("#{python} -c 'import cv2; print(cv2.__version__)'")
      assert_equal version.to_s, output.chomp
    end
  end
end
