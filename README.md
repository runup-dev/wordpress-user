# 워드프레스 호스팅계정 생성

아래의 절차로 프로세스가 수행됩니다

1. 유저생성
2. PHP OPCACHE BLACKLIST 생성 ( wp-config.php 보안강화 )
3. 데이터베이스 생성
4. PHP-FPM POLL 생성
5. NGINX CONFG 생성
6. LET'S ENCRYPT 인증서 생성
7. 테스트 접속
8. 워드프레스 코어설치 
9. RSA 페어생성 및 개인키 배포 


# 시스템요구사항
- centos7
- let's encrtypt certbot 

# 사용방법
SUDO권한이 있는 유저로 로그인후 아래 코드를 실행합니다 
<pre>
<code>
./setClien.sh -u {유저이름} -d {도메인} -p {패스워드}
</code>
</pre>

- 다운로드한 개인키를 안전한 장소에 보관하고 접속을 테스트하세요
- 사용자 계정 및 DB정보는 같은 폴더내 info.txt에 기록합니다 안전한 장소에 기록하고 파일을 삭제하세요 
 
# 템플릿 수정 
계정정보의 패턴 / PHP-FPM / NGINX 환경파일은 템플릿으로 관리되고 있습니다 기본세팅 설정을 변경하시려면 아래 템플릿 파일을 수정하세요
NGINX 및PHP-FPM 기본설정을 변경하고 싶은경우 템플릿 파일을 수정해서 사용하세요
- nginx-root-domain.conf.tmpl : 루트도메인에 대한 nginx 템플릿
- nginx-service-domain.conf.tmpl : 주도메인에 대한 nginx 템플릿
- php-fpm-pool.conf.tmpl : php-fpm-pool 템플릿
- account.tmpl : 사용자 계정 / 개인키 비밀번호 / DB 접속정보를 스크립트 실행시 전달한 인자와 결합하는 방식을 정의하고 있습니다

