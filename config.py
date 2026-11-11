# 프로젝트 공통 설정
# 재현하는 사람은 PROJECT_ID만 본인 Google Cloud 프로젝트 ID로 바꾸면 됨

PROJECT_ID = "dailyglow-analytics-514401"  # BigQuery 프로젝트 ID
LOCATION = "asia-northeast3"               # 데이터셋 리전 (서울)

SEED = 42                                  # 데이터 생성 난수 시드 (같은 데이터 재현용)

# 쿼리 1회 최대 처리량 (넘으면 실행하지 않고 에러) - 요금 안전장치
MAX_BYTES_BILLED = 10 * 1024**3            # 10GB
