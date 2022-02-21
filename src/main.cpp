#include <iostream>
#include <thread>
#include <chrono>
using namespace std::literals::chrono_literals;

#include "test.hpp"

namespace ui
{
  struct Window
  {
    bool mRunning = false;


    
    bool setContextVersion(int major, int minor) { return true; }
    int run()
    {
      mRunning = true;
      while(mRunning)
        {
          std::cout << "DONE --> " << G_TEST() << "\n";
          std::this_thread::sleep_for(200ms);
        }
      return 0;
    }
  };
}

int main(int argc, char *argv[])
{
  ui::Window window;
  window.setContextVersion(4, 6);

  
  int status = window.run();
  return status;
}
