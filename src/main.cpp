#include <GLFW/glfw3.h>
// #include <glad/glad.h>
// #include "glad.h"
#include <iostream>
#include <unistd.h>
#include <vector>
#include <fstream>
#include <sstream>
#include <string>

#include "../include/shader.hpp"

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

// unsigned int SCR_SIZE = 0;
unsigned int samples = 1;

bool cameraMoved = false;

#define WIDTH	1920
#define HEIGHT	1080

void	processInput(GLFWwindow *window);
GLuint createFramebuffer(GLuint *texture);

void	cam_movement(glm::vec3& camPos, glm::vec3 camDir,GLFWwindow* window);
void	RecalculateView(glm::vec3 camPos, glm::vec3 camDir, glm::mat4& m_View, glm::mat4& m_InverseView);
void	RecalculateRayDirections(glm::mat4& m_Projection, glm::mat4& m_InverseProjection);
void	cam_orientation(glm::vec3 camPos, glm::vec3& camDir, glm::vec2& lastMousePos, GLFWwindow* window, \
							glm::mat4& m_View, glm::mat4& m_InverseView, glm::mat4& m_Projection, glm::mat4& m_InverseProjection);

// settings


void update_camera(GLuint fb1, GLuint fb2)
{
	glBindFramebuffer(GL_FRAMEBUFFER, fb1);
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	// glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	// Clear framebuffer 2
	glBindFramebuffer(GL_FRAMEBUFFER, fb2);
	// glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	// Reset cameraMoved flag
	cameraMoved = false;
	samples = 1;
}

int	main(int argc, char *argv[])
{
	// glfw: initialize and configure
	// ------------------------------
	glfwInit();
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

	srand(time(NULL));
#ifdef __APPLE__
	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif
	// glfw window creation
	// --------------------
	GLFWwindow *window =
			glfwCreateWindow(WIDTH, HEIGHT, "Ray Tracer", NULL, NULL);
	if (window == NULL) {
		std::cout << "Failed to create GLFW window" << std::endl;
		glfwTerminate();
		return -1;
	}
	glfwMakeContextCurrent(window);

	// glad: load all OpenGL function pointers
	// ---------------------------------------
	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
		std::cout << "Failed to initialize GLAD" << std::endl;
		return -1;
	}
	//
	// Build and compile our shader zprogram
	// Note: Paths to shader files should be relative to location of executable
	Shader shader("../shaders/vert.glsl", "../shaders/frag.glsl");
	Shader copyShader("../shaders/vert.glsl", "../shaders/copy.glsl");
	Shader dispShader("../shaders/vert.glsl", "../shaders/disp.glsl");

	float vertices[] = {
			-1, -1, -1, +1, +1, +1, -1, -1, +1, +1, +1, -1,
	};

	GLuint VBO, VAO;
	glGenVertexArrays(1, &VAO);
	glGenBuffers(1, &VBO);

	glBindVertexArray(VAO);

	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

	// Position attribute
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void *)0);
	glEnableVertexAttribArray(0);

	// Create two needed framebuffers
	GLuint fbTexture1;
	GLuint fb1 = createFramebuffer(&fbTexture1);
	GLuint fbTexture2;
	GLuint fb2 = createFramebuffer(&fbTexture2);

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, fbTexture1);
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, fbTexture2);

	// Store start time
	double t0 = glfwGetTime();
	glDisable(GL_DEPTH_TEST);
	glm::vec3 camPosition = glm::vec3(0.0f, 0.0f, -15.0f);
	glm::vec3 camDirection = glm::vec3(0.0f, 0.0f, 1.0f);
	glm::mat4 viewMat{ 1.0f };
	glm::mat4 invViewMat{ 1.0f };
	glm::mat4 m_Projection{ 1.0f };
	glm::mat4 m_InverseProjection{ 1.0f };
	glm::vec2 lastMousePos(0.0f, 0.0f);
	RecalculateView(camPosition, camDirection, viewMat, invViewMat);
	RecalculateRayDirections(m_Projection, m_InverseProjection);
	cameraMoved = false;
	// cameraMoved = true;
	double lastTime = glfwGetTime();
	int frameCount = 0;
	float total_frames = 0;
	while (!glfwWindowShouldClose(window))
	{
		double currentTime = glfwGetTime();
		frameCount++;
		if (currentTime - lastTime >= 1.0) {
			// Update window title with FPS information
			std::string title = "Ray Tracer - FPS: " + std::to_string(frameCount);
			glfwSetWindowTitle(window, title.c_str());

			// Reset frame count and last update time
			frameCount = 0;
			lastTime = currentTime;
		}
		// input
		// -----
		cam_movement(camPosition, camDirection, window);
		cam_orientation(camPosition, camDirection, lastMousePos, window, viewMat, invViewMat, m_Projection, m_InverseProjection);
		processInput(window);

		// cameraMoved = true;
		if (cameraMoved == true)
		{
			// std::cout << "Camera moved" << std::endl;
			update_camera(fb1, fb2);
		}

		// Render pass on fb1
		glBindFramebuffer(GL_FRAMEBUFFER, fb1);
		shader.use();
		shader.setInt("prevFrame", 1);
		shader.setVec2("resolution", glm::vec2(WIDTH, HEIGHT));
		shader.setFloat("checkerboard", 2);
		shader.setVec3("u_camPosition", camPosition);
		shader.setFloat("u_samples", samples);
		shader.setFloat("u_frames", total_frames);
		shader.setInt("seedInit", rand());
		shader.setMat4("_invView", invViewMat);
		shader.setMat4("_invProjection", m_InverseProjection);

		glBindVertexArray(VAO);
		glDrawArrays(GL_TRIANGLES, 0, sizeof(vertices) / 3);

		// Copy to fb2
		glBindFramebuffer(GL_FRAMEBUFFER, fb2);
		glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		GLuint ID = copyShader.ID;
		copyShader.use();
		copyShader.setInt("fb", 0);
		glUniform2f(glGetUniformLocation(ID, "resolution"), WIDTH, HEIGHT);
		glBindVertexArray(VAO);
		glDrawArrays(GL_TRIANGLES, 0, sizeof(vertices) / 3);
		// samples += 1;

		// Render to screen
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);

		dispShader.use();
		ID = dispShader.ID;

		// Render from fb2 texture
		dispShader.setFloat("exposure", 5);
		dispShader.setInt("screenTexture", 0);
		dispShader.setInt("samples", samples);

		glUniform2f(glGetUniformLocation(ID, "resolution"), WIDTH, HEIGHT);
		glBindVertexArray(VAO);
		glDrawArrays(GL_TRIANGLES, 0, sizeof(vertices) / 3);

		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved
		// etc.)
		// -------------------------------------------------------------------------------
		glfwSwapBuffers(window);
		glfwPollEvents();

		std::cout << "Progress: " << samples << " samples"
							<< '\r';

		samples++;
		total_frames++;
	}

	std::cout << "INFO::Time taken: " << glfwGetTime() - t0 << "s" << std::endl;

	// Deallocate all resources once they've outlived their purpose
	glDeleteVertexArrays(1, &VAO);
	glDeleteBuffers(1, &VBO);
	glDeleteFramebuffers(1, &fb1);
	glDeleteFramebuffers(1, &fb2);
	glDeleteTextures(1, &fbTexture1);
	glDeleteTextures(1, &fbTexture2);

	// glfw: terminate, clearing all previously allocated GLFW resources.
	// ------------------------------------------------------------------
	glfwTerminate();
	return 0;
}

// process all input: query GLFW whether relevant keys are pressed/released this
// frame and react accordingly
// ---------------------------------------------------------------------------------------------------------
void processInput(GLFWwindow *window)
{
	if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS) {
		glfwSetWindowShouldClose(window, true);
	}
}

GLuint createFramebuffer(GLuint *texture) {
	// Create a framebuffer to write output to
	GLuint fb;
	glGenFramebuffers(1, &fb);
	glBindFramebuffer(GL_FRAMEBUFFER, fb);

	// Create a texture to write to
	glGenTextures(1, texture);
	glBindTexture(GL_TEXTURE_2D, *texture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, WIDTH, HEIGHT, 0, GL_RGBA,
							 GL_FLOAT, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glBindTexture(GL_TEXTURE_2D, 0);

	// Attach texture to framebuffer
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
												 *texture, 0);

	// Check if framebuffer is ready to be written to
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
		std::cout << "ERROR::FRAMEBUFFER:: Framebuffer is not complete!"
							<< std::endl;
	}

	return fb;
}

void	cam_movement(glm::vec3& camPos, glm::vec3 camDir,GLFWwindow* window)
{
	float speed = 0.01f;
	glm::vec3 upDirection(0.0f, 1.0f, 0.0f);
	glm::vec3 rightDirection = glm::cross(camDir, upDirection);
	if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
	{
		camPos += speed * camDir;
		cameraMoved = true;
	}
	if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
	{
		camPos += speed * rightDirection;
		cameraMoved = true;
	}
	if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
	{
		camPos -= speed * camDir;
		cameraMoved = true;
	}
	if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
	{
		camPos -= speed * rightDirection;
		cameraMoved = true;
	}
	if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS)
	{
		camPos += speed * upDirection;
		cameraMoved = true;
	}
	if (glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS)
	{
		camPos -= speed * upDirection;
		cameraMoved = true;
	}
}

void	RecalculateView(glm::vec3 camPos, glm::vec3 camDir, glm::mat4& m_View, glm::mat4& m_InverseView)
{
	m_View = glm::lookAt(camPos, camPos + camDir, glm::vec3(0.0f, 1.0f, 0.0f));
	m_InverseView = glm::inverse(m_View);
}

void	RecalculateRayDirections(glm::mat4& m_Projection, glm::mat4& m_InverseProjection)
{
	m_Projection = glm::perspective(glm::radians(45.0f), (float)WIDTH / (float)HEIGHT, 0.1f, 100.0f);
	m_InverseProjection = glm::inverse(m_Projection);
}

void	cam_orientation(glm::vec3 camPos, glm::vec3& camDir, glm::vec2& lastMousePos, GLFWwindow* window, \
							glm::mat4& m_View, glm::mat4& m_InverseView, glm::mat4& m_Projection, glm::mat4& m_InverseProjection)
{
	float speed = 0.01f;
	// glm::vec3 upDirection(0.0f, 1.0f, 0.0f);
	// glm::vec3 rightDirection = glm::cross(camDir, upDirection);

	double _mouseX;
	double _mouseY;
	glfwGetCursorPos(window, &_mouseX, &_mouseY);
	glm::vec2 mousePos(_mouseX, _mouseY);

	glm::vec2 delta = (mousePos - lastMousePos) * speed;
	lastMousePos = mousePos;

	float rotSpeed = 0.1f;
	if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS)
	{
		glm::vec3 upDirection(0.0f, 1.0f, 0.0f);
		glm::vec3 rightDirection = glm::cross(camDir, upDirection);

		float pitchDelta = delta.y * rotSpeed;
		float yawDelta = -delta.x * rotSpeed;

		glm::quat q = glm::normalize(glm::cross(glm::angleAxis(-pitchDelta, rightDirection),
			glm::angleAxis(-yawDelta, glm::vec3(0.f, 1.0f, 0.0f))));
		// camDir = glm::rotate(q, camDir);
		glm::quat camDirQuat(0.0f, camDir.x, camDir.y, camDir.z);
		camDirQuat = q * camDirQuat * glm::conjugate(q);
		camDir = glm::vec3(camDirQuat.x, camDirQuat.y, camDirQuat.z);

		RecalculateView(camPos, camDir, m_View, m_InverseView);
		RecalculateRayDirections(m_Projection, m_InverseProjection);
		cameraMoved = true;
	}
}