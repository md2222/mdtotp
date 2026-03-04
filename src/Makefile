APP_NAME = mdtotp

SOURCES = $(wildcard *.vala)

PKGS = --pkg gtk+-3.0 \
       --pkg libxml-2.0 \
       --pkg gdk-3.0 \
       --pkg posix \
       --pkg gio-2.0 \
       --pkg openssl \
       --pkg openssl-extra --vapidir=. --Xcc=-lcrypto

C_FLAGS = -X -loath

all:
#	valac -D DEBUG $(PKGS) $(SOURCES) -o $(APP_NAME) $(C_FLAGS)
	valac $(PKGS) $(SOURCES) -o $(APP_NAME) $(C_FLAGS)

release:
	valac $(PKGS) $(SOURCES) -o $(APP_NAME) $(C_FLAGS)

clean:
	rm -f $(APP_NAME)

run: all
	./$(APP_NAME)
