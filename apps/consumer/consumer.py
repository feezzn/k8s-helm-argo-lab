import logging
import os
import signal
import sys
import time

from confluent_kafka import Consumer, KafkaException


logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)

running = True


def handle_shutdown(signum, _frame):
    global running
    logging.info("received signal=%s, finishing current message before shutdown", signum)
    running = False


signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)

bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka.kafka.svc.cluster.local:9092")
topic = os.getenv("KAFKA_TOPIC", "orders")
group_id = os.getenv("KAFKA_GROUP_ID", "orders-consumer")
processing_seconds = float(os.getenv("PROCESSING_SECONDS", "2"))

consumer = Consumer(
    {
        "bootstrap.servers": bootstrap_servers,
        "group.id": group_id,
        "auto.offset.reset": "earliest",
        "enable.auto.commit": False,
    }
)

logging.info(
    "starting consumer bootstrap_servers=%s topic=%s group_id=%s processing_seconds=%s",
    bootstrap_servers,
    topic,
    group_id,
    processing_seconds,
)

consumer.subscribe([topic])

try:
    while running:
        message = consumer.poll(1.0)
        if message is None:
            continue

        if message.error():
            raise KafkaException(message.error())

        value = message.value().decode("utf-8", errors="replace")
        logging.info(
            "processing topic=%s partition=%s offset=%s value=%s",
            message.topic(),
            message.partition(),
            message.offset(),
            value,
        )

        time.sleep(processing_seconds)
        consumer.commit(message=message, asynchronous=False)
        logging.info("committed offset=%s", message.offset())
finally:
    logging.info("closing consumer")
    consumer.close()
    sys.exit(0)
