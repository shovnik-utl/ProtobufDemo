/*
 * protobuf_client.c
 * Encodes random SensorReading messages and sends them over TCP.
 * Frame format: 4-byte big-endian length prefix + protobuf payload.
 * Build: make   Run: ./protobuf_client
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#include <pb_encode.h>
#include <pb_decode.h>
#include "sensor.pb.h"

#define HOST "127.0.0.1"
#define PORT 5555
#define INTERVAL_MS 1000
#define MAX_MSG_SIZE 512

static uint64_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static float randf(float lo, float hi) {
    return lo + (hi - lo) * ((float)rand() / RAND_MAX);
}

static void fill_reading(iot_SensorReading *r, iot_Vec3 *accel, uint32_t uptime) {
    iot_sensor_reading__init(r);
    iot_vec3__init(accel);

    int _;
    r->timestamp_ms  = now_ms();
    r->temperature   = randf(18.0f, 35.0f);
    r->humidity      = randf(30.0f, 90.0f);
    r->pressure      = randf(1000.0f, 1025.0f);
    r->uptime_s      = uptime;
    r->status        = ((_=rand() % 3), _> 1 ? iot_SensorStatus_FAULT
                                      : _> 0 ? iot_SensorStatus_WARNING
                                      :        iot_SensorStatus_OK);

    accel->x         = randf(-0.1f, 0.1f);
    accel->y         = randf(-0.1f, 0.1f);
    accel->z         = randf(0.95f, 1.05f);   /* ~1g vertical */
    r->accelerometer = *accel; // Copy.

    /* fill in random value (eg: temperature) for the device ID to ensure uniqueness (best effort). */
    memcpy(&r->device_id, &r->temperature, sizeof(r->temperature));
}

int main(void) {
    srand((unsigned)time(NULL));

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) { perror("socket"); return 1; }

    struct sockaddr_in srv = {
        .sin_family = AF_INET,
        .sin_port   = htons(PORT),
    };
    inet_pton(AF_INET, HOST, &srv.sin_addr);

    if (connect(fd, (struct sockaddr *)&srv, sizeof(srv)) < 0) {
        perror("connect"); return 1;
    }
    printf("Connected to %s:%d\n", HOST, PORT);

    uint8_t buf[MAX_MSG_SIZE];
    uint32_t uptime = 0;

    int nmessages_sent = 0;

    while (1) {
        iot_SensorReading reading;
        iot_Vec3 accel;
        fill_reading(&reading, &accel, uptime);

        size_t len = iot_sensor_reading__get_packed_size(&reading);
        iot_sensor_reading__pack(&reading, buf);

        /* 4-byte big-endian length prefix */
        uint32_t prefix = htonl((uint32_t)len);
        if (send(fd, &prefix, 4, 0) != 4 ||
            send(fd, buf, len, 0) != (ssize_t)len) {
            perror("send"); break;
        }
        nmessages_sent++;

        printf("Sent %zu bytes (uptime=%us, id=%d)\n", len, uptime, reading.device_id);
        uptime++;
        usleep(INTERVAL_MS * 1000);
    }

    printf("%d messages sent.\n", nmessages_sent);
    close(fd);
    return 0;
}