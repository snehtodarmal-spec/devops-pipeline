// ─────────────────────────────────────────────────────────────────
// Jenkinsfile — Declarative Pipeline
//
// This file IS the pipeline. Jenkins reads it directly from your
// GitHub repo on every triggered build. No job config in the UI.
//
// Flow:
//   GitHub push → webhook → Jenkins → Checkout → Install → Test
//   → SonarQube scan → Quality gate → Docker build
//   → Push to registry → Deploy locally
// ─────────────────────────────────────────────────────────────────

pipeline {

    // Run this pipeline on the built-in Jenkins node (our local machine).
    // In a real setup this would say 'agent { label "linux" }' to target
    // a specific build agent. For local dev, "any" is fine.
    agent any

    // ── Environment variables ──────────────────────────────────────
    // These are available in every stage as env.VARIABLE_NAME.
    // Secrets come from Jenkins credentials store (set via casc.yaml)
    // — never hardcoded here.
    environment {
        // Docker image name — used in build, push, and deploy stages
        IMAGE_NAME        = "devops-pipeline-app"
        // Registry URL — localhost:5000 for Phase 1, DockerHub for Phase 2
        REGISTRY_URL      = "localhost:5000"
        // Full image tag includes build number so every build is traceable.
        // env.BUILD_NUMBER is injected by Jenkins automatically.
        IMAGE_TAG         = "${env.BUILD_NUMBER}"
        // Full image reference used to push and pull from the registry
        FULL_IMAGE        = "${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
        // SonarQube host — matches the server name defined in casc.yaml
        SONAR_HOST_URL    = "http://sonarqube:9000"
    }

    // ── Pipeline-wide options ──────────────────────────────────────
    options {
        // Kill the build if it runs longer than 20 minutes.
        // Prevents stuck builds from blocking the executor forever.
        timeout(time: 20, unit: 'MINUTES')
        // Add timestamps to every line of console output.
        // Makes it easy to see how long each stage takes.
        timestamps()
        // Keep logs for the last 10 builds only — saves disk space.
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Don't allow the same pipeline to run twice simultaneously.
        // Prevents race conditions on the Docker registry.
        disableConcurrentBuilds()
    }

    // ── Stages ────────────────────────────────────────────────────
    // Each stage shows up as a separate column in the Jenkins
    // Stage View UI. If any stage fails, all subsequent stages
    // are skipped and the build is marked FAILED.
    stages {

        // ── Stage 1: Checkout ──────────────────────────────────────
        // Jenkins clones your GitHub repo into the workspace.
        // When triggered by a webhook, it checks out the exact
        // commit that triggered the build.
        stage('Checkout') {
            steps {
                // scm is a special Jenkins variable that refers to the
                // Source Control Management config defined in the job.
                // It uses the GitHub URL and credentials from casc.yaml.
                checkout scm
                // Print the commit hash so we know exactly what code
                // we're building. Useful for tracing bugs back to commits.
                sh 'git log -1 --oneline'
            }
        }

        // ── Stage 2: Install dependencies ─────────────────────────
        // Runs npm install inside the app/ directory.
        // We use --ci instead of install because:
        //   - it's faster (uses package-lock.json exactly)
        //   - it fails if package-lock.json is out of sync
        //   - it never updates the lockfile (safe for CI)
        stage('Install') {
            steps {
                dir('app') {
                    // dir() changes the working directory for commands
                    // inside the block — equivalent to cd app && npm ci
                    sh '''
                        echo "Installing dependencies..."
                        npm ci
                        echo "Dependencies installed successfully"
                    '''
                }
            }
        }

        // ── Stage 3: Test ──────────────────────────────────────────
        // Runs Jest tests with coverage reporting.
        // --coverage tells Jest to generate lcov report which
        // SonarQube reads in the next stage to show coverage %.
        // If any test fails, this stage fails and we never reach
        // SonarQube or Docker — no point scanning broken code.
        stage('Test') {
            steps {
                dir('app') {
                    sh '''
                        echo "Running test suite..."
                        npm test -- --coverage --forceExit
                    '''
                }
            }
            // post runs after the stage regardless of pass/fail.
            // junit publishes test results to Jenkins so you can
            // see them in the build report without reading raw logs.
            post {
                always {
                    // Publish Jest test results (requires jest-junit reporter)
                    // We'll add jest-junit to package.json in a moment
                    junit allowEmptyResults: true,
                          testResults: 'app/junit.xml'
                }
            }
        }

        // ── Stage 4: SonarQube analysis ───────────────────────────
        // Runs the SonarQube scanner against our source code.
        // withSonarQubeEnv() injects the server URL and auth token
        // from the Jenkins credentials store automatically —
        // we never touch the token directly in this file.
        stage('SonarQube Analysis') {
            steps {
                // The string 'SonarQube' must match the installation
                // name defined in casc.yaml under sonarGlobalConfiguration
                withSonarQubeEnv('SonarQube') {
                    // SonarScanner must match the tool name in casc.yaml
                    // under sonarRunnerInstallation
                    sh '''
                        echo "Running SonarQube analysis..."
                        ${SONAR_SCANNER_HOME}/bin/sonar-scanner \
                            -Dsonar.projectKey=devops-pipeline-app \
                            -Dsonar.sources=app/src \
                            -Dsonar.tests=app/test \
                            -Dsonar.javascript.lcov.reportPaths=app/coverage/lcov.info
                    '''
                }
            }
        }

        // ── Stage 5: Quality gate ──────────────────────────────────
        // Waits for SonarQube to finish processing the scan results
        // and checks if the quality gate passed or failed.
        //
        // Quality gate = a set of conditions in SonarQube like:
        //   - Coverage must be > 80%
        //   - No new critical bugs
        //   - No new security vulnerabilities
        //
        // If the gate fails → build fails → no Docker image is built.
        // This is the whole point: broken/insecure code never ships.
        stage('Quality Gate') {
            steps {
                // timeout prevents Jenkins waiting forever if
                // SonarQube is slow or unreachable
                timeout(time: 5, unit: 'MINUTES') {
                    // abortPipeline: true means a failed gate = failed build
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ── Stage 6: Docker build ──────────────────────────────────
        // Builds the Docker image from our Dockerfile.
        // Tags it with the build number so we can trace exactly
        // which Jenkins build produced which image.
        stage('Docker Build') {
            steps {
                sh '''
                    echo "Building Docker image: ${FULL_IMAGE}"
                    docker build \
                        --tag ${FULL_IMAGE} \
                        --tag ${REGISTRY_URL}/${IMAGE_NAME}:latest \
                        --label "build=${BUILD_NUMBER}" \
                        --label "commit=${GIT_COMMIT}" \
                        .
                    echo "Image built successfully"
                    docker images | grep ${IMAGE_NAME}
                '''
            }
        }

        // ── Stage 7: Push to registry ──────────────────────────────
        // Pushes the built image to our local private registry.
        // In Phase 2 this stage changes to push to DockerHub/ECR —
        // only the registry URL and credentials change, nothing else.
        stage('Push to Registry') {
            steps {
                sh '''
                    echo "Pushing image to local registry..."
                    docker push ${FULL_IMAGE}
                    docker push ${REGISTRY_URL}/${IMAGE_NAME}:latest
                    echo "Image pushed successfully"
                '''
            }
        }

        // ── Stage 8: Deploy ────────────────────────────────────────
        // Pulls the image from the registry and runs it as a container.
        // We call deploy.sh to keep the Jenkinsfile clean —
        // the script handles stopping the old container gracefully
        // before starting the new one.
        stage('Deploy') {
            steps {
                sh '''
                    echo "Deploying application..."
                    chmod +x scripts/deploy.sh
                    ./scripts/deploy.sh ${FULL_IMAGE}
                '''
            }
        }
    }

    // ── Post-pipeline actions ──────────────────────────────────────
    // These run after ALL stages complete, regardless of outcome.
    post {
        // Runs only if the build succeeded
        success {
            echo "Pipeline completed successfully! Image: ${FULL_IMAGE}"
            echo "App should be running at http://localhost:3000"
        }
        // Runs only if the build failed
        failure {
            echo "Pipeline failed at stage: ${FAILED_STAGE}"
            echo "Check the console output above for details"
        }
        // Runs after every build no matter what — good for cleanup
        always {
            // Clean up dangling Docker images to save disk space.
            // The || true prevents this from failing the build if
            // there are no dangling images to remove.
            sh 'docker image prune -f || true'
        }
    }
}
