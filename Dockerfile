FROM golang:1.21-alpine
WORKDIR /app
COPY . .
# This adds the file required by the task
RUN echo "Wiz Exercise Verification: Success" > wizexercise.txt
RUN go build -o tasky .
EXPOSE 8080
CMD ["./tasky"]
